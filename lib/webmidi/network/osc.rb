# frozen_string_literal: true

require "socket"

module Webmidi
  module Network
    module OSC
      DEFAULT_MAPPINGS = {
        Webmidi::Message::Channel::NoteOn => "/midi/note/on",
        Webmidi::Message::Channel::NoteOff => "/midi/note/off",
        Webmidi::Message::Channel::ControlChange => "/midi/cc",
        Webmidi::Message::Channel::ProgramChange => "/midi/program",
        Webmidi::Message::Channel::PitchBend => "/midi/pitch_bend",
        Webmidi::Message::Channel::ChannelPressure => "/midi/pressure",
        Webmidi::Message::Channel::PolyphonicPressure => "/midi/poly_pressure"
      }.freeze

      module_function

      def bridge(midi_input: nil, osc_host: "127.0.0.1", osc_port: 9000, mapping: :default)
        Bridge.new(midi_input: midi_input, osc_host: osc_host, osc_port: osc_port, mapping: mapping)
      end

      module Encoder
        module_function

        def encode_message(address, *args)
          data = encode_string(address)
          type_tag = ","
          args_data = String.new(encoding: Encoding::ASCII_8BIT)

          args.each do |arg|
            case arg
            when Integer
              type_tag += "i"
              args_data += [arg].pack("N")
            when Float
              type_tag += "f"
              args_data += [arg].pack("g")
            when String
              type_tag += "s"
              args_data += encode_string(arg)
            end
          end

          data + encode_string(type_tag) + args_data
        end

        def encode_string(str)
          padded = str + "\0"
          padded += "\0" until (padded.bytesize % 4).zero?
          padded.b
        end

        def decode_message(data)
          address, offset = decode_string(data, 0)
          type_tag, offset = decode_string(data, offset)
          type_tag = type_tag[1..]

          args = []
          type_tag.each_char do |t|
            case t
            when "i"
              args << data[offset, 4].unpack1("N")
              offset += 4
            when "f"
              args << data[offset, 4].unpack1("g")
              offset += 4
            when "s"
              str, offset = decode_string(data, offset)
              args << str
            end
          end

          [address, args]
        end

        def decode_string(data, offset)
          null_pos = data.index("\0", offset)
          str = data[offset...null_pos]
          new_offset = null_pos + 1
          new_offset += 1 until (new_offset % 4).zero?
          [str, new_offset]
        end
      end

      class Bridge
        attr_reader :mapping

        def initialize(midi_input: nil, osc_host: "127.0.0.1", osc_port: 9000, mapping: :default)
          @midi_input = midi_input
          @osc_host = osc_host
          @osc_port = osc_port
          @mapping = mapping == :default ? DEFAULT_MAPPINGS.dup : mapping
          @socket = nil
          @running = false
        end

        def start
          @socket = UDPSocket.new
          @running = true
          @midi_input&.on_message { |msg| send_osc(msg) }
          self
        end

        def stop
          @running = false
          @socket&.close
          @socket = nil
          self
        end

        def send_osc(message)
          return unless @running && @socket

          address = @mapping[message.class]
          return unless address

          args = midi_to_osc_args(message)
          data = Encoder.encode_message(address, *args)
          @socket.send(data, 0, @osc_host, @osc_port)
        end

        def custom_mapping(&block)
          block.call(@mapping)
          self
        end

        private

        def midi_to_osc_args(message)
          case message
          when Message::Channel::NoteOn
            [message.channel, message.note, message.velocity]
          when Message::Channel::NoteOff
            [message.channel, message.note, message.velocity]
          when Message::Channel::ControlChange
            [message.channel, message.cc, message.value]
          when Message::Channel::ProgramChange
            [message.channel, message.program]
          when Message::Channel::PitchBend
            [message.channel, message.value]
          when Message::Channel::ChannelPressure
            [message.channel, message.pressure]
          when Message::Channel::PolyphonicPressure
            [message.channel, message.note, message.pressure]
          else
            message.to_bytes
          end
        end
      end
    end
  end
end
