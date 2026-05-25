# frozen_string_literal: true

require "socket"
require_relative "../callback_subscription"

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

      DEFAULT_REVERSE_MAPPINGS = {
        "/midi/note/on" => ->(args) { Message.note_on(args[1], velocity: args[2], channel: args[0]) },
        "/midi/note/off" => ->(args) { Message.note_off(args[1], velocity: args[2], channel: args[0]) },
        "/midi/cc" => ->(args) { Message.control_change(args[1], args[2], channel: args[0]) },
        "/midi/program" => ->(args) { Message.program_change(args[1], channel: args[0]) },
        "/midi/pitch_bend" => ->(args) { Message.pitch_bend(args[1], channel: args[0]) },
        "/midi/pressure" => ->(args) { Message.channel_pressure(args[1], channel: args[0]) },
        "/midi/poly_pressure" => ->(args) { Message.polyphonic_pressure(args[1], args[2], channel: args[0]) }
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
          raise InvalidMessageError, "OSC type tag must start with comma" unless type_tag.start_with?(",")

          type_tag = type_tag[1..]

          args = []
          type_tag.each_char do |t|
            case t
            when "i"
              ensure_available!(data, offset, 4)
              args << data[offset, 4].unpack1("N")
              offset += 4
            when "f"
              ensure_available!(data, offset, 4)
              args << data[offset, 4].unpack1("g")
              offset += 4
            when "s"
              str, offset = decode_string(data, offset)
              args << str
            else
              raise InvalidMessageError, "Unsupported OSC argument type: #{t.inspect}"
            end
          end

          [address, args]
        end

        def decode_string(data, offset)
          raise InvalidMessageError, "OSC string offset out of bounds" if offset >= data.bytesize

          null_pos = data.index("\0", offset)
          raise InvalidMessageError, "OSC string missing null terminator" unless null_pos

          str = data[offset...null_pos]
          new_offset = null_pos + 1
          new_offset += 1 until (new_offset % 4).zero?
          raise InvalidMessageError, "OSC string padding exceeds packet length" if new_offset > data.bytesize

          [str, new_offset]
        end

        def ensure_available!(data, offset, length)
          return if offset + length <= data.bytesize

          raise InvalidMessageError, "OSC packet ended while reading argument"
        end

        private_class_method :ensure_available!
      end

      class Bridge
        attr_reader :mapping, :reverse_mapping

        def initialize(midi_input: nil, midi_output: nil, osc_host: "127.0.0.1", osc_port: 9000, mapping: :default,
                       reverse_mapping: :default)
          @midi_input = midi_input
          @midi_output = midi_output
          @osc_host = osc_host
          @osc_port = osc_port
          @mapping = mapping == :default ? DEFAULT_MAPPINGS.dup : mapping
          @reverse_mapping = reverse_mapping == :default ? DEFAULT_REVERSE_MAPPINGS.dup : reverse_mapping
          @socket = nil
          @running = false
          @subscription = nil
        end

        def start
          return self if @running

          @socket = UDPSocket.new
          @running = true
          @subscription = @midi_input&.on_message { |msg| send_osc(msg) }
          self
        end

        def stop
          @running = false
          @subscription&.unsubscribe
          @subscription = nil
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

        def receive_osc(data)
          address, args = Encoder.decode_message(data)
          message = osc_to_midi(address, args)
          @midi_output&.send(message) if message
          message
        end

        def osc_to_midi(address, args)
          mapper = @reverse_mapping[address]
          mapper&.call(args)
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
