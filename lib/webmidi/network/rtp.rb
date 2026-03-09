# frozen_string_literal: true

require "socket"
require "securerandom"

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
          @sequence_number = sequence_number
          @timestamp = timestamp
          @ssrc = ssrc
          @midi_data = midi_data
        end

        def to_bytes
          header = [
            (PROTOCOL_VERSION << 6) | 0x00,
            MIDI_PAYLOAD_TYPE,
            @sequence_number & 0xFFFF
          ].pack("CCn")

          header += [@timestamp, @ssrc].pack("NN")

          midi_bytes = @midi_data.flatten
          header += [midi_bytes.size].pack("C")
          header += midi_bytes.pack("C*")

          header
        end

        def self.parse(bytes)
          return nil if bytes.bytesize < 12

          _flags, _pt, seq = bytes[0, 4].unpack("CCn")
          timestamp, ssrc = bytes[4, 8].unpack("NN")
          midi_length = bytes.getbyte(12)
          midi_data = bytes[13, midi_length]&.bytes || []

          new(
            sequence_number: seq,
            timestamp: timestamp,
            ssrc: ssrc,
            midi_data: midi_data
          )
        end
      end

      class Session
        attr_reader :name, :peers

        def initialize(port:, name:, mode: :server)
          @port = port
          @name = name
          @mode = mode
          @ssrc = SecureRandom.random_number(0xFFFFFFFF)
          @sequence_number = 0
          @peers = []
          @callbacks = []
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

        def port
          @port
        end

        def connect_to(host, port)
          start unless @running
          @mutex.synchronize { @peers << { host: host, port: port } }
          self
        end

        def send(message)
          bytes = case message
                  when Message::Base
                    message.to_bytes
                  when Array
                    message
                  else
                    raise InvalidMessageError, "Expected Message or Array"
                  end

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
          @mutex.synchronize { @callbacks << block }
          self
        end

        def close
          stop
        end

        private

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

              message = Message.from_bytes(packet.midi_data)
              @mutex.synchronize { @callbacks.dup }.each { |cb| cb.call(message) }
            rescue IO::WaitReadable
              IO.select([@socket], nil, nil, 0.1)
            rescue IOError
              break
            end
          end
        end
      end
    end
  end
end
