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

      WORD_COUNTS = {
        utility: 1,
        system_common: 1,
        channel_voice_32: 1,
        data_64: 2,
        channel_voice_64: 2,
        data_128: 4,
        flex_data: 4
      }.freeze

      STATUS_NIBBLES = {
        note_off: 0x8,
        note_on: 0x9,
        poly_pressure: 0xA,
        control_change: 0xB,
        program_change: 0xC,
        channel_pressure: 0xD,
        pitch_bend: 0xE
      }.freeze

      STATUS_BY_NIBBLE = STATUS_NIBBLES.invert.freeze

      CHANNEL_VOICE_32_STATUSES = %i[
        note_off note_on poly_pressure control_change program_change channel_pressure pitch_bend
      ].freeze
      CHANNEL_VOICE_64_STATUSES = %i[
        note_off note_on poly_pressure control_change program_change channel_pressure pitch_bend
      ].freeze

      class Base < Message::Base
        attr_reader :message_type, :group

        def initialize(message_type:, group: 0, timestamp: nil)
          validate_message_type!(message_type)
          validate_range!(group, "Group", 0, 15)
          @message_type = message_type
          @group = group
          super(timestamp: timestamp)
        end

        def deconstruct_keys(keys)
          { message_type: @message_type, group: @group }
        end

        private

        def validate_message_type!(message_type)
          return if MESSAGE_TYPES.key?(message_type)

          raise InvalidMessageError, "Unknown UMP message type: #{message_type.inspect}"
        end

        def validate_range!(value, name, min, max)
          return if value.is_a?(Integer) && value.between?(min, max)

          raise InvalidMessageError, "#{name} must be between #{min} and #{max}, got #{value.inspect}"
        end
      end

      class Raw < Base
        attr_reader :words

        def initialize(message_type:, words:, group: 0, timestamp: nil)
          validate_words!(words)
          validate_word_count!(message_type, words)
          @words = words.dup.freeze
          super(message_type: message_type, group: group, timestamp: timestamp)
        end

        def to_bytes
          words_to_bytes(@words)
        end

        def deconstruct_keys(keys)
          super.merge(words: @words)
        end

        private

        def validate_words!(words)
          unless words.respond_to?(:each)
            raise InvalidMessageError, "UMP words must be enumerable, got #{words.class}"
          end

          words.each_with_index do |word, index|
            validate_range!(word, "Word at index #{index}", 0, 0xFFFF_FFFF)
          end
        end

        def validate_word_count!(message_type, words)
          expected = WORD_COUNTS.fetch(message_type)
          return if words.size == expected

          raise InvalidMessageError, "#{message_type} UMP must have #{expected} word(s), got #{words.size}"
        end

        def words_to_bytes(words)
          words.flat_map do |word|
            [(word >> 24) & 0xFF, (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]
          end
        end
      end

      class Utility < Raw
        def initialize(words:, group: 0, timestamp: nil)
          super(message_type: :utility, words: words, group: group, timestamp: timestamp)
        end
      end

      class SystemCommon < Raw
        def initialize(words:, group: 0, timestamp: nil)
          super(message_type: :system_common, words: words, group: group, timestamp: timestamp)
        end
      end

      class Data64 < Raw
        def initialize(words:, group: 0, timestamp: nil)
          super(message_type: :data_64, words: words, group: group, timestamp: timestamp)
        end
      end

      class Data128 < Raw
        def initialize(words:, group: 0, timestamp: nil)
          super(message_type: :data_128, words: words, group: group, timestamp: timestamp)
        end
      end

      class FlexData < Raw
        def initialize(words:, group: 0, timestamp: nil)
          super(message_type: :flex_data, words: words, group: group, timestamp: timestamp)
        end
      end

      class ChannelVoice64 < Base
        attr_reader :status, :channel, :note, :velocity, :attribute_type, :attribute

        def initialize(status:, channel: 0, note: 0, velocity: 0, attribute_type: 0, attribute: 0, group: 0,
                       timestamp: nil)
          validate_status!(status)
          validate_range!(channel, "Channel", 0, 15)
          validate_range!(note, "Note/controller", 0, 127)
          validate_range!(attribute_type, "Attribute type", 0, 255)
          validate_range!(attribute, "Attribute", 0, 0xFFFF)
          validate_velocity!(status, velocity)

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
                  (status_nibble << 20) |
                  (@channel << 16) |
                  (@note << 8) |
                  data2
          word2 = word2_value

          [(word1 >> 24) & 0xFF, (word1 >> 16) & 0xFF, (word1 >> 8) & 0xFF, word1 & 0xFF,
           (word2 >> 24) & 0xFF, (word2 >> 16) & 0xFF, (word2 >> 8) & 0xFF, word2 & 0xFF]
        end

        def deconstruct_keys(keys)
          super.merge(
            status: @status, channel: @channel, note: @note, velocity: @velocity,
            attribute_type: @attribute_type, attribute: @attribute
          )
        end

        private

        def validate_status!(status)
          return if CHANNEL_VOICE_64_STATUSES.include?(status)

          raise InvalidMessageError, "Unknown MIDI 2.0 channel voice status: #{status.inspect}"
        end

        def validate_velocity!(status, velocity)
          max = %i[note_on note_off poly_pressure].include?(status) ? 0xFFFF : 0xFFFF_FFFF
          validate_range!(velocity, "Value", 0, max)
        end

        def status_nibble
          STATUS_NIBBLES.fetch(@status)
        end

        def data2
          %i[note_on note_off poly_pressure].include?(@status) ? @attribute_type : 0
        end

        def word2_value
          if %i[note_on note_off poly_pressure].include?(@status)
            (@velocity << 16) | @attribute
          else
            @velocity
          end
        end
      end

      class ChannelVoice32 < Base
        attr_reader :status, :channel, :data1, :data2

        def initialize(status:, channel: 0, data1: 0, data2: 0, group: 0, timestamp: nil)
          validate_status!(status)
          validate_range!(channel, "Channel", 0, 15)
          validate_range!(data1, "Data byte 1", 0, 127)
          validate_range!(data2, "Data byte 2", 0, 127)
          @status = status
          @channel = channel
          @data1 = data1
          @data2 = data2
          super(message_type: :channel_voice_32, group: group, timestamp: timestamp)
        end

        def to_bytes
          word = (MESSAGE_TYPES[:channel_voice_32] << 28) |
                 (@group << 24) |
                 (status_nibble << 20) |
                 (@channel << 16) |
                 (@data1 << 8) |
                 @data2

          [(word >> 24) & 0xFF, (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]
        end

        def deconstruct_keys(keys)
          super.merge(status: @status, channel: @channel, data1: @data1, data2: @data2)
        end

        private

        def validate_status!(status)
          return if CHANNEL_VOICE_32_STATUSES.include?(status)

          raise InvalidMessageError, "Unknown MIDI 1.0 channel voice status: #{status.inspect}"
        end

        def status_nibble
          STATUS_NIBBLES.fetch(@status)
        end
      end

      module_function

      def from_bytes(*bytes)
        bytes = bytes.flatten
        unless bytes.size.positive? && (bytes.size % 4).zero?
          raise InvalidMessageError, "UMP byte input must be a positive multiple of 4 bytes"
        end

        words = bytes.each_slice(4).map do |slice|
          slice.each_with_index do |byte, index|
            unless byte.is_a?(Integer) && byte.between?(0, 255)
              raise InvalidMessageError, "Byte at index #{index} must be between 0 and 255, got #{byte.inspect}"
            end
          end
          (slice[0] << 24) | (slice[1] << 16) | (slice[2] << 8) | slice[3]
        end
        from_words(*words)
      end

      def from_words(*words)
        words = words.flatten
        validate_words!(words)
        message_type = type_from_word(words.first)
        expected_words = WORD_COUNTS.fetch(message_type) do
          raise InvalidMessageError, "Unsupported UMP message type: #{format("0x%X", words.first >> 28)}"
        end
        return parse_words(message_type, words) if words.size == expected_words

        raise InvalidMessageError, "#{message_type} UMP expects #{expected_words} word(s), got #{words.size}"
      end

      def upgrade(midi1_message, group: Webmidi.configuration.default_group)
        case midi1_message
        when Channel::NoteOn
          ChannelVoice64.new(
            status: :note_on,
            channel: midi1_message.channel,
            note: midi1_message.note,
            velocity: scale_7_to_16(midi1_message.velocity),
            group: group
          )
        when Channel::NoteOff
          ChannelVoice64.new(
            status: :note_off,
            channel: midi1_message.channel,
            note: midi1_message.note,
            velocity: scale_7_to_16(midi1_message.velocity),
            group: group
          )
        when Channel::ControlChange
          ChannelVoice64.new(
            status: :control_change,
            channel: midi1_message.channel,
            note: midi1_message.cc,
            velocity: scale_7_to_32(midi1_message.value),
            group: group
          )
        when Channel::PitchBend
          ChannelVoice64.new(
            status: :pitch_bend,
            channel: midi1_message.channel,
            velocity: scale_14_to_32(midi1_message.value),
            group: group
          )
        else
          raise InvalidMessageError, "Cannot upgrade #{midi1_message.class} to MIDI 2.0"
        end
      end

      def downgrade(midi2_message)
        case midi2_message
        when ChannelVoice64
          downgrade_channel_voice64(midi2_message)
        else
          raise InvalidMessageError, "Cannot downgrade #{midi2_message.class} to MIDI 1.0"
        end
      end

      def parse_words(message_type, words)
        group = (words.first >> 24) & 0x0F
        case message_type
        when :channel_voice_32
          parse_channel_voice32(words.first, group)
        when :channel_voice_64
          parse_channel_voice64(words, group)
        when :utility
          Utility.new(words: words, group: group)
        when :system_common
          SystemCommon.new(words: words, group: group)
        when :data_64
          Data64.new(words: words, group: group)
        when :data_128
          Data128.new(words: words, group: group)
        when :flex_data
          FlexData.new(words: words, group: group)
        end
      end

      def parse_channel_voice32(word, group)
        status = status_from_nibble((word >> 20) & 0x0F)
        ChannelVoice32.new(
          status: status,
          channel: (word >> 16) & 0x0F,
          data1: (word >> 8) & 0x7F,
          data2: word & 0x7F,
          group: group
        )
      end

      def parse_channel_voice64(words, group)
        word1, word2 = words
        status = status_from_nibble((word1 >> 20) & 0x0F)
        data1 = (word1 >> 8) & 0xFF
        data2 = word1 & 0xFF

        if %i[note_on note_off poly_pressure].include?(status)
          ChannelVoice64.new(
            status: status,
            channel: (word1 >> 16) & 0x0F,
            note: data1,
            velocity: (word2 >> 16) & 0xFFFF,
            attribute_type: data2,
            attribute: word2 & 0xFFFF,
            group: group
          )
        else
          ChannelVoice64.new(
            status: status,
            channel: (word1 >> 16) & 0x0F,
            note: data1,
            velocity: word2,
            group: group
          )
        end
      end

      def downgrade_channel_voice64(message)
        case message.status
        when :note_on
          Channel::NoteOn.new(
            note: message.note,
            velocity: scale_16_to_7(message.velocity),
            channel: message.channel
          )
        when :note_off
          Channel::NoteOff.new(
            note: message.note,
            velocity: scale_16_to_7(message.velocity),
            channel: message.channel
          )
        when :control_change
          Channel::ControlChange.new(
            cc: message.note,
            value: scale_32_to_7(message.velocity),
            channel: message.channel
          )
        when :pitch_bend
          Channel::PitchBend.new(
            value: scale_32_to_14(message.velocity),
            channel: message.channel
          )
        else
          raise InvalidMessageError, "Cannot downgrade status #{message.status}"
        end
      end

      def type_from_word(word)
        type = (word >> 28) & 0x0F
        MESSAGE_TYPES.key(type)
      end

      def status_from_nibble(nibble)
        STATUS_BY_NIBBLE.fetch(nibble) do
          raise InvalidMessageError, "Unknown channel voice status nibble: #{format("0x%X", nibble)}"
        end
      end

      def validate_words!(words)
        raise InvalidMessageError, "UMP words cannot be empty" if words.empty?

        words.each_with_index do |word, index|
          next if word.is_a?(Integer) && word.between?(0, 0xFFFF_FFFF)

          raise InvalidMessageError, "Word at index #{index} must be between 0 and 0xFFFFFFFF, got #{word.inspect}"
        end
      end

      def scale_7_to_16(value)
        ((value * 0xFFFF).to_f / 0x7F).round
      end

      def scale_16_to_7(value)
        ((value * 0x7F).to_f / 0xFFFF).round.clamp(0, 127)
      end

      def scale_7_to_32(value)
        ((value * 0xFFFF_FFFF).to_f / 0x7F).round
      end

      def scale_32_to_7(value)
        ((value * 0x7F).to_f / 0xFFFF_FFFF).round.clamp(0, 127)
      end

      def scale_14_to_32(value)
        ((value * 0xFFFF_FFFF).to_f / 0x3FFF).round
      end

      def scale_32_to_14(value)
        ((value * 0x3FFF).to_f / 0xFFFF_FFFF).round.clamp(0, 16_383)
      end

      private_class_method :parse_words, :parse_channel_voice32, :parse_channel_voice64,
                           :downgrade_channel_voice64, :type_from_word, :status_from_nibble,
                           :validate_words!, :scale_7_to_16, :scale_16_to_7,
                           :scale_7_to_32, :scale_32_to_7, :scale_14_to_32,
                           :scale_32_to_14
    end
  end
end
