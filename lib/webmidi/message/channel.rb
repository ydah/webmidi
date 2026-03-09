# frozen_string_literal: true

module Webmidi
  module Message
    module Channel
      class Base < Message::Base
        attr_reader :channel

        private

        def validate_channel!(channel)
          unless channel.is_a?(Integer) && channel.between?(0, 15)
            raise InvalidMessageError, "Channel must be between 0 and 15, got #{channel.inspect}"
          end
        end

        def validate_byte!(value, name)
          unless value.is_a?(Integer) && value.between?(0, 127)
            raise InvalidMessageError, "#{name} must be between 0 and 127, got #{value.inspect}"
          end
        end
      end

      class NoteOn < Base
        attr_reader :note, :velocity

        def initialize(note:, velocity: 100, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(note, "Note")
          validate_byte!(velocity, "Velocity")
          @note = note
          @velocity = velocity
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0x90 | @channel, @note, @velocity]
        end

        def deconstruct_keys(keys)
          { note: @note, velocity: @velocity, channel: @channel }
        end
      end

      class NoteOff < Base
        attr_reader :note, :velocity

        def initialize(note:, velocity: 0, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(note, "Note")
          validate_byte!(velocity, "Velocity")
          @note = note
          @velocity = velocity
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0x80 | @channel, @note, @velocity]
        end

        def deconstruct_keys(keys)
          { note: @note, velocity: @velocity, channel: @channel }
        end
      end

      class PolyphonicPressure < Base
        attr_reader :note, :pressure

        def initialize(note:, pressure:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(note, "Note")
          validate_byte!(pressure, "Pressure")
          @note = note
          @pressure = pressure
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xA0 | @channel, @note, @pressure]
        end

        def deconstruct_keys(keys)
          { note: @note, pressure: @pressure, channel: @channel }
        end
      end

      class ControlChange < Base
        attr_reader :cc, :value

        def initialize(cc:, value:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(cc, "CC")
          validate_byte!(value, "Value")
          @cc = cc
          @value = value
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xB0 | @channel, @cc, @value]
        end

        def deconstruct_keys(keys)
          { cc: @cc, value: @value, channel: @channel }
        end
      end

      class ProgramChange < Base
        attr_reader :program

        def initialize(program:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(program, "Program")
          @program = program
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xC0 | @channel, @program]
        end

        def deconstruct_keys(keys)
          { program: @program, channel: @channel }
        end
      end

      class ChannelPressure < Base
        attr_reader :pressure

        def initialize(pressure:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          validate_byte!(pressure, "Pressure")
          @pressure = pressure
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xD0 | @channel, @pressure]
        end

        def deconstruct_keys(keys)
          { pressure: @pressure, channel: @channel }
        end
      end

      class PitchBend < Base
        attr_reader :value

        def initialize(value:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          unless value.is_a?(Integer) && value.between?(0, 16383)
            raise InvalidMessageError, "Pitch bend value must be between 0 and 16383, got #{value.inspect}"
          end
          @value = value
          @channel = channel
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xE0 | @channel, @value & 0x7F, (@value >> 7) & 0x7F]
        end

        def deconstruct_keys(keys)
          { value: @value, channel: @channel }
        end
      end
    end
  end
end
