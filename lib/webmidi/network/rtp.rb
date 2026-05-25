# frozen_string_literal: true

require "socket"
require "securerandom"
require_relative "../callback_subscription"

module Webmidi
  module Network
    module RTP
      PROTOCOL_VERSION = 2
      MIDI_PAYLOAD_TYPE = 97

      class ControlPacket
        SIGNATURE = 0xFFFF
        PROTOCOL_VERSION = 2
        COMMANDS = {
          invitation: "IN",
          accepted: "OK",
          rejected: "NO",
          synchronization: "CK",
          receiver_feedback: "RS",
          end_session: "BY"
        }.freeze
        COMMAND_BY_CODE = COMMANDS.invert.freeze

        attr_reader :command, :version, :token, :ssrc, :name, :count, :timestamps, :sequence_number

        def initialize(command:, version: PROTOCOL_VERSION, token: 0, ssrc: 0, name: "", count: 0,
          timestamps: [], sequence_number: 0)
          raise InvalidMessageError, "Unknown AppleMIDI command: #{command.inspect}" unless COMMANDS.key?(command)
          self.class.validate_range!(version, "Protocol version", 0, 0xFFFF_FFFF)
          self.class.validate_range!(token, "Initiator token", 0, 0xFFFF_FFFF)
          self.class.validate_range!(ssrc, "SSRC", 0, 0xFFFF_FFFF)
          self.class.validate_range!(count, "Synchronization count", 0, 3)
          self.class.validate_range!(sequence_number, "Sequence number", 0, 0xFFFF)

          @command = command
          @version = version
          @token = token
          @ssrc = ssrc
          @name = name.to_s
          @count = count
          @timestamps = timestamps.dup.freeze
          @sequence_number = sequence_number
        end

        def self.invitation(token:, ssrc:, name:, version: PROTOCOL_VERSION)
          new(command: :invitation, version: version, token: token, ssrc: ssrc, name: name)
        end

        def self.accepted(token:, ssrc:, name:, version: PROTOCOL_VERSION)
          new(command: :accepted, version: version, token: token, ssrc: ssrc, name: name)
        end

        def self.rejected(token:, ssrc:, name:, version: PROTOCOL_VERSION)
          new(command: :rejected, version: version, token: token, ssrc: ssrc, name: name)
        end

        def self.synchronization(ssrc:, count:, timestamps:)
          new(command: :synchronization, ssrc: ssrc, count: count, timestamps: timestamps)
        end

        def self.receiver_feedback(ssrc:, sequence_number:)
          new(command: :receiver_feedback, ssrc: ssrc, sequence_number: sequence_number)
        end

        def self.end_session(ssrc:)
          new(command: :end_session, ssrc: ssrc)
        end

        def to_bytes
          header = [SIGNATURE].pack("n") + COMMANDS.fetch(@command)
          header + payload_bytes
        end

        def self.parse(bytes)
          return nil if bytes.bytesize < 4

          signature = bytes[0, 2].unpack1("n")
          command = COMMAND_BY_CODE[bytes[2, 2]]
          return nil unless signature == SIGNATURE && command

          parse_payload(command, bytes[4..] || "")
        end

        def self.parse_payload(command, payload)
          case command
          when :invitation, :accepted, :rejected
            return nil if payload.bytesize < 12

            version, token, ssrc = payload[0, 12].unpack("NNN")
            name = (payload[12..] || "").split("\0", 2).first
            new(command: command, version: version, token: token, ssrc: ssrc, name: name)
          when :synchronization
            return nil if payload.bytesize < 28

            ssrc = payload[0, 4].unpack1("N")
            count = payload.getbyte(4)
            timestamps = payload[8, 24].unpack("Q>Q>Q>")
            new(command: command, ssrc: ssrc, count: count, timestamps: timestamps)
          when :receiver_feedback
            return nil if payload.bytesize < 6

            ssrc, sequence_number = payload[0, 6].unpack("Nn")
            new(command: command, ssrc: ssrc, sequence_number: sequence_number)
          when :end_session
            return nil if payload.bytesize < 4

            new(command: command, ssrc: payload[0, 4].unpack1("N"))
          end
        end

        def self.timestamp
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1_000_000).to_i
        end

        def self.validate_range!(value, name, min, max)
          return if value.is_a?(Integer) && value.between?(min, max)

          raise InvalidMessageError, "#{name} must be between #{min} and #{max}, got #{value.inspect}"
        end

        private

        def payload_bytes
          case @command
          when :invitation, :accepted, :rejected
            [@version, @token, @ssrc].pack("NNN") + "#{@name}\0".b
          when :synchronization
            padded = @timestamps.first(3)
            padded << 0 while padded.size < 3
            [@ssrc, @count].pack("NC") + "\0\0\0" + padded.pack("Q>Q>Q>")
          when :receiver_feedback
            [@ssrc, @sequence_number].pack("Nn")
          when :end_session
            [@ssrc].pack("N")
          end
        end
      end

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
        attr_reader :name, :ssrc

        def initialize(port:, name:, mode: :server, ssrc: SecureRandom.random_number(0xFFFFFFFF))
          @port = port
          @name = name
          @mode = mode
          @ssrc = ssrc
          @sequence_number = 0
          @peers = []
          @callbacks = []
          @control_callbacks = []
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

        def on_control_packet(&block)
          raise ArgumentError, "on_control_packet requires a block" unless block

          @mutex.synchronize { @control_callbacks << block }
          CallbackSubscription.new do
            @mutex.synchronize { @control_callbacks.delete(block) }
          end
        end

        def send_control_packet(packet, host, port)
          start unless @running
          @socket&.send(packet.to_bytes, 0, host, port)
          self
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
              data, address = @socket.recvfrom_nonblock(1024)
              control_packet = ControlPacket.parse(data)
              if control_packet
                notify_control_packet(control_packet, address)
                next
              end

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

        def notify_control_packet(packet, address)
          peer = {host: address[3], port: address[1]}
          callbacks = @mutex.synchronize { @control_callbacks.dup }
          callbacks.each { |cb| cb.call(packet, peer) }
        end

        def notify_error(error, data = nil)
          callbacks = @mutex.synchronize { @error_callbacks.dup }
          callbacks.each { |cb| cb.call(error, data) }
        end
      end
    end
  end
end
