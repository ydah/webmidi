# frozen_string_literal: true

module Webmidi
  module Message
    module UMP
      MESSAGE_TYPES = {
        utility: 0x0,
        system_common: 0x1,
        channel_voice_32: 0x2,
        data_64: 0x3,
        channel_voice_64: 0x4,
        data_128: 0x5,
        flex_data: 0xD
      }.freeze

      class Base < Message::Base
        attr_reader :message_type, :group

        def initialize(message_type:, group: 0, timestamp: nil)
          @message_type = message_type
          @group = group
          super(timestamp: timestamp)
        end

        def deconstruct_keys(keys)
          { message_type: @message_type, group: @group }
        end
      end

      class ChannelVoice64 < Base
        attr_reader :status, :channel, :note, :velocity, :attribute_type, :attribute

        def initialize(status:, channel: 0, note: 0, velocity: 0, attribute_type: 0, attribute: 0, group: 0, timestamp: nil)
          @status = status
          @channel = channel
          @note = note
          @velocity = velocity
          @attribute_type = attribute_type
          @attribute = attribute
          super(message_type: :channel_voice_64, group: group, timestamp: timestamp)
        end

        def to_bytes
          word1 = (MESSAGE_TYPES[:channel_voice_64] << 28) |
                  (@group << 24) |
                  (status_byte << 16) |
                  (@channel << 8) |
                  @note
          word2 = (@attribute_type << 24) |
                  (@velocity << 16) |
                  @attribute

          [(word1 >> 24) & 0xFF, (word1 >> 16) & 0xFF, (word1 >> 8) & 0xFF, word1 & 0xFF,
           (word2 >> 24) & 0xFF, (word2 >> 16) & 0xFF, (word2 >> 8) & 0xFF, word2 & 0xFF]
        end

        def deconstruct_keys(keys)
          {
            message_type: @message_type, group: @group,
            status: @status, channel: @channel,
            note: @note, velocity: @velocity,
            attribute_type: @attribute_type, attribute: @attribute
          }
        end

        private

        def status_byte
          case @status
          when :note_off then 0x80
          when :note_on then 0x90
          when :poly_pressure then 0xA0
          when :control_change then 0xB0
          when :program_change then 0xC0
          when :channel_pressure then 0xD0
          when :pitch_bend then 0xE0
          else 0x00
          end
        end
      end

      class ChannelVoice32 < Base
        attr_reader :status, :channel, :data1, :data2

        def initialize(status:, channel: 0, data1: 0, data2: 0, group: 0, timestamp: nil)
          @status = status
          @channel = channel
          @data1 = data1
          @data2 = data2
          super(message_type: :channel_voice_32, group: group, timestamp: timestamp)
        end

        def to_bytes
          word = (MESSAGE_TYPES[:channel_voice_32] << 28) |
                 (@group << 24) |
                 (status_byte << 16) |
                 (@channel << 12) |
                 (@data1 << 8) |
                 @data2

          [(word >> 24) & 0xFF, (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]
        end

        def deconstruct_keys(keys)
          {
            message_type: @message_type, group: @group,
            status: @status, channel: @channel,
            data1: @data1, data2: @data2
          }
        end

        private

        def status_byte
          case @status
          when :note_off then 0x8
          when :note_on then 0x9
          when :poly_pressure then 0xA
          when :control_change then 0xB
          when :program_change then 0xC
          when :channel_pressure then 0xD
          when :pitch_bend then 0xE
          else 0x0
          end
        end
      end

      module_function

      def upgrade(midi1_message)
        case midi1_message
        when Channel::NoteOn
          ChannelVoice64.new(
            status: :note_on,
            channel: midi1_message.channel,
            note: midi1_message.note,
            velocity: midi1_message.velocity << 9
          )
        when Channel::NoteOff
          ChannelVoice64.new(
            status: :note_off,
            channel: midi1_message.channel,
            note: midi1_message.note,
            velocity: midi1_message.velocity << 9
          )
        when Channel::ControlChange
          ChannelVoice64.new(
            status: :control_change,
            channel: midi1_message.channel,
            note: midi1_message.cc,
            velocity: midi1_message.value << 25
          )
        when Channel::PitchBend
          ChannelVoice64.new(
            status: :pitch_bend,
            channel: midi1_message.channel,
            velocity: midi1_message.value << 18
          )
        else
          raise InvalidMessageError, "Cannot upgrade #{midi1_message.class} to MIDI 2.0"
        end
      end

      def downgrade(midi2_message)
        case midi2_message
        when ChannelVoice64
          case midi2_message.status
          when :note_on
            Channel::NoteOn.new(
              note: midi2_message.note,
              velocity: (midi2_message.velocity >> 9).clamp(0, 127),
              channel: midi2_message.channel
            )
          when :note_off
            Channel::NoteOff.new(
              note: midi2_message.note,
              velocity: (midi2_message.velocity >> 9).clamp(0, 127),
              channel: midi2_message.channel
            )
          when :control_change
            Channel::ControlChange.new(
              cc: midi2_message.note,
              value: (midi2_message.velocity >> 25).clamp(0, 127),
              channel: midi2_message.channel
            )
          when :pitch_bend
            Channel::PitchBend.new(
              value: (midi2_message.velocity >> 18).clamp(0, 16383),
              channel: midi2_message.channel
            )
          else
            raise InvalidMessageError, "Cannot downgrade status #{midi2_message.status}"
          end
        else
          raise InvalidMessageError, "Cannot downgrade #{midi2_message.class} to MIDI 1.0"
        end
      end
    end
  end
end
