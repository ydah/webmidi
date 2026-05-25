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
        CONTROLLERS = {
          bank_select: 0,
          modulation: 1,
          breath_controller: 2,
          foot_controller: 4,
          portamento_time: 5,
          data_entry_msb: 6,
          volume: 7,
          balance: 8,
          pan: 10,
          expression: 11,
          sustain: 64,
          portamento: 65,
          sostenuto: 66,
          soft_pedal: 67,
          legato: 68,
          hold_2: 69,
          sound_variation: 70,
          resonance: 71,
          release_time: 72,
          attack_time: 73,
          brightness: 74,
          all_sound_off: 120,
          reset_all_controllers: 121,
          local_control: 122,
          all_notes_off: 123,
          omni_off: 124,
          omni_on: 125,
          mono_on: 126,
          poly_on: 127
        }.freeze

        ALL_NOTES_OFF = CONTROLLERS[:all_notes_off]

        attr_reader :cc, :value

        def initialize(cc:, value:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          cc = self.class.controller_number(cc)
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

        def self.controller_number(controller)
          return controller if controller.is_a?(Integer)

          key = controller.to_sym if controller.respond_to?(:to_sym)
          return CONTROLLERS[key] if key && CONTROLLERS.key?(key)

          raise InvalidMessageError, "Unknown control change controller: #{controller.inspect}"
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
        MIN = 0
        CENTER = 8192
        MAX = 16_383
        SIGNED_MIN = -8192
        SIGNED_MAX = 8191

        attr_reader :value

        def initialize(value:, channel: 0, timestamp: nil)
          validate_channel!(channel)
          unless value.is_a?(Integer) && value.between?(MIN, MAX)
            raise InvalidMessageError, "Pitch bend value must be between #{MIN} and #{MAX}, got #{value.inspect}"
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

        def signed_value
          @value - CENTER
        end

        def self.from_signed(value, channel: 0, timestamp: nil)
          unless value.is_a?(Integer) && value.between?(SIGNED_MIN, SIGNED_MAX)
            raise InvalidMessageError,
                  "Signed pitch bend value must be between #{SIGNED_MIN} and #{SIGNED_MAX}, got #{value.inspect}"
          end

          new(value: value + CENTER, channel: channel, timestamp: timestamp)
        end
      end
    end
  end
end
