# frozen_string_literal: true

require "socket"
require "securerandom"
require_relative "../callback_subscription"

module Webmidi
  module Network
    module RTP
      PROTOCOL_VERSION = 2
      MIDI_PAYLOAD_TYPE = 97

      module_function

      def server(port: 5004, name: "Webmidi")
        Session.new(port: port, name: name, mode: :server)
      end

      def connect(host, port: 5004)
        session = Session.new(port: 0, name: "Webmidi Client", mode: :client)
        session.connect_to(host, port)
        session
      end

      class Packet
        attr_reader :sequence_number, :timestamp, :ssrc, :midi_data

        def initialize(sequence_number:, timestamp:, ssrc:, midi_data:)
          self.class.validate_range!(sequence_number, "Sequence number", 0, 0xFFFF)
          self.class.validate_range!(timestamp, "Timestamp", 0, 0xFFFF_FFFF)
          self.class.validate_range!(ssrc, "SSRC", 0, 0xFFFF_FFFF)
          self.class.validate_midi_data!(midi_data)
          @sequence_number = sequence_number
          @timestamp = timestamp
          @ssrc = ssrc
          @midi_data = midi_data.dup.freeze
        end

        def to_bytes
          midi_bytes = @midi_data.flatten
          header = [
            (PROTOCOL_VERSION << 6) | 0x00,
            MIDI_PAYLOAD_TYPE,
            @sequence_number & 0xFFFF
          ].pack("CCn")

          header += [@timestamp, @ssrc].pack("NN")

          header += [midi_bytes.size].pack("n")
          header += midi_bytes.pack("C*")

          header
        end

        def self.parse(bytes)
          return nil if bytes.bytesize < 14

          flags, payload_type, seq = bytes[0, 4].unpack("CCn")
          return nil unless (flags >> 6) == PROTOCOL_VERSION
          return nil unless payload_type == MIDI_PAYLOAD_TYPE

          timestamp, ssrc = bytes[4, 8].unpack("NN")
          midi_length = bytes[12, 2].unpack1("n")
          return nil unless bytes.bytesize == 14 + midi_length

          midi_data = bytes[14, midi_length].bytes

          new(
            sequence_number: seq,
            timestamp: timestamp,
            ssrc: ssrc,
            midi_data: midi_data
          )
        end

        def self.validate_range!(value, name, min, max)
          return if value.is_a?(Integer) && value.between?(min, max)

          raise InvalidMessageError, "#{name} must be between #{min} and #{max}, got #{value.inspect}"
        end

        def self.validate_midi_data!(midi_data)
          unless midi_data.respond_to?(:each)
            raise InvalidMessageError, "MIDI data must be enumerable, got #{midi_data.class}"
          end

          midi_data.each_with_index do |byte, index|
            next if byte.is_a?(Integer) && byte.between?(0, 255)

            raise InvalidMessageError, "MIDI data byte #{index} must be between 0 and 255, got #{byte.inspect}"
          end
        end
      end

      class Session
        attr_reader :name

        def initialize(port:, name:, mode: :server)
          @port = port
          @name = name
          @mode = mode
          @ssrc = SecureRandom.random_number(0xFFFFFFFF)
          @sequence_number = 0
          @peers = []
          @callbacks = []
          @error_callbacks = []
          @mutex = Mutex.new
          @running = false
          @socket = nil
        end

        def start
          @socket = UDPSocket.new
          @socket.bind("0.0.0.0", @port)
          @port = @socket.addr[1] if @port.zero?
          @running = true
          @receive_thread = Thread.new { receive_loop }
          self
        end

        def stop
          @running = false
          @socket&.close
          @receive_thread&.join(1)
          self
        end

        attr_reader :port

        def connect_to(host, port)
          start unless @running
          add_peer(host, port)
          self
        end

        def add_peer(host, port)
          validate_peer!(host, port)
          peer = {host: host, port: port}
          @mutex.synchronize { @peers << peer unless @peers.include?(peer) }
          self
        end

        def remove_peer(host, port)
          @mutex.synchronize { @peers.delete({host: host, port: port}) }
          self
        end

        def peers
          @mutex.synchronize { @peers.map(&:dup) }
        end

        def send(message)
          bytes = outbound_midi_bytes(message)

          packet = Packet.new(
            sequence_number: next_sequence,
            timestamp: (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i,
            ssrc: @ssrc,
            midi_data: bytes
          )

          packet_bytes = packet.to_bytes
          @mutex.synchronize do
            @peers.each { |peer| @socket&.send(packet_bytes, 0, peer[:host], peer[:port]) }
          end
          self
        end

        def on_message(&block)
          raise ArgumentError, "on_message requires a block" unless block

          @mutex.synchronize { @callbacks << block }
          CallbackSubscription.new do
            @mutex.synchronize { @callbacks.delete(block) }
          end
        end

        def on_error(&block)
          raise ArgumentError, "on_error requires a block" unless block

          @mutex.synchronize { @error_callbacks << block }
          CallbackSubscription.new do
            @mutex.synchronize { @error_callbacks.delete(block) }
          end
        end

        def close
          stop
        end

        private

        def outbound_midi_bytes(message)
          case message
          when Message::Base
            message.to_bytes
          when Array
            return Message.parse_many(message, normalize_note_on_zero: false).flat_map(&:to_bytes) if message.all?(Integer)

            message.compact.flat_map { |item| outbound_midi_bytes(item) }
          else
            raise InvalidMessageError, "Expected Message or Array"
          end
        end

        def next_sequence
          @mutex.synchronize do
            seq = @sequence_number
            @sequence_number = (@sequence_number + 1) & 0xFFFF
            seq
          end
        end

        def receive_loop
          while @running
            begin
              data, = @socket.recvfrom_nonblock(1024)
              packet = Packet.parse(data)
              next unless packet

              messages = Message.parse_many(packet.midi_data).map { |message| message.with(timestamp: packet.timestamp) }
              callbacks = @mutex.synchronize { @callbacks.dup }
              messages.each { |message| callbacks.each { |cb| cb.call(message) } }
            rescue IO::WaitReadable
              break unless @running

              begin
                IO.select([@socket], nil, nil, 0.1)
              rescue IOError, SystemCallError
                break
              end
            rescue IOError, SystemCallError
              break
            rescue => e
              notify_error(e, data)
            end
          end
        end

        def validate_peer!(host, port)
          raise NetworkError, "Peer host must not be empty" if host.to_s.empty?
          return if port.is_a?(Integer) && port.between?(1, 65_535)

          raise NetworkError, "Peer port must be between 1 and 65535, got #{port.inspect}"
        end

        def notify_error(error, data = nil)
          callbacks = @mutex.synchronize { @error_callbacks.dup }
          callbacks.each { |cb| cb.call(error, data) }
        end
      end
    end
  end
end
