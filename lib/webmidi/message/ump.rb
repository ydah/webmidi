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

      MIDI1_CHANNEL_VOICE_TO_UMP = {
        Channel::NoteOff => {status: :note_off, data: :note, value: :velocity, scale: :scale_7_to_16},
        Channel::NoteOn => {status: :note_on, data: :note, value: :velocity, scale: :scale_7_to_16},
        Channel::PolyphonicPressure => {status: :poly_pressure, data: :note, value: :pressure, scale: :scale_7_to_16},
        Channel::ControlChange => {status: :control_change, data: :cc, value: :value, scale: :scale_7_to_32},
        Channel::ProgramChange => {status: :program_change, data: :program},
        Channel::ChannelPressure => {status: :channel_pressure, value: :pressure, scale: :scale_7_to_32},
        Channel::PitchBend => {status: :pitch_bend, value: :value, scale: :scale_14_to_32}
      }.freeze

      UMP_CHANNEL_VOICE_TO_MIDI1 = {
        note_off: {class: Channel::NoteOff, fields: {note: :note, velocity: [:velocity, :scale_16_to_7]}},
        note_on: {class: Channel::NoteOn, fields: {note: :note, velocity: [:velocity, :scale_16_to_7]}},
        poly_pressure: {
          class: Channel::PolyphonicPressure,
          fields: {note: :note, pressure: [:velocity, :scale_16_to_7]}
        },
        control_change: {class: Channel::ControlChange, fields: {cc: :note, value: [:velocity, :scale_32_to_7]}},
        program_change: {class: Channel::ProgramChange, fields: {program: :note}},
        channel_pressure: {class: Channel::ChannelPressure, fields: {pressure: [:velocity, :scale_32_to_7]}},
        pitch_bend: {class: Channel::PitchBend, fields: {value: [:velocity, :scale_32_to_14]}}
      }.freeze

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
          {message_type: @message_type, group: @group}
        end

        def with(**changes)
          changes = changes.dup
          next_timestamp = changes.key?(:timestamp) ? changes.delete(:timestamp) : @timestamp
          self.class.new(**constructor_attributes.merge(changes), timestamp: next_timestamp)
        end

        private

        def constructor_attributes
          attributes = deconstruct_keys(nil)
          attributes.delete(:message_type) unless instance_of?(Base) || instance_of?(Raw)
          attributes
        end

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
          words = normalize_words!(words)
          validate_word_count!(message_type, words)
          validate_range!(group, "Group", 0, 15)
          validate_word_header!(message_type, group, words.first)
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

        def normalize_words!(words)
          unless words.respond_to?(:each)
            raise InvalidMessageError, "UMP words must be enumerable, got #{words.class}"
          end

          words = words.to_a
          words.each_with_index do |word, index|
            validate_range!(word, "Word at index #{index}", 0, 0xFFFF_FFFF)
          end
          words
        end

        def validate_word_count!(message_type, words)
          expected = WORD_COUNTS.fetch(message_type)
          return if words.size == expected

          raise InvalidMessageError, "#{message_type} UMP must have #{expected} word(s), got #{words.size}"
        end

        def validate_word_header!(message_type, group, word)
          actual_type = (word >> 28) & 0x0F
          expected_type = MESSAGE_TYPES.fetch(message_type)
          unless actual_type == expected_type
            raise InvalidMessageError,
              "#{message_type} UMP first word has message type 0x#{actual_type.to_s(16).upcase}"
          end

          actual_group = (word >> 24) & 0x0F
          return if actual_group == group

          raise InvalidMessageError,
            "#{message_type} UMP first word has group #{actual_group}, got group #{group}"
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
        spec = MIDI1_CHANNEL_VOICE_TO_UMP.find { |message_class, _| midi1_message.is_a?(message_class) }&.last
        unless spec
          raise InvalidMessageError, "Cannot upgrade #{midi1_message.class} to MIDI 2.0"
        end

        ChannelVoice64.new(**upgrade_attributes(midi1_message, spec, group))
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
        spec = UMP_CHANNEL_VOICE_TO_MIDI1[message.status]
        unless spec
          raise InvalidMessageError, "Cannot downgrade status #{message.status}"
        end

        spec[:class].new(**downgrade_attributes(message, spec))
      end

      def upgrade_attributes(message, spec, group)
        attributes = {status: spec.fetch(:status), channel: message.channel, group: group}
        attributes[:note] = message.public_send(spec[:data]) if spec[:data]
        attributes[:velocity] = scaled_value(message.public_send(spec[:value]), spec[:scale]) if spec[:value]
        attributes
      end

      def downgrade_attributes(message, spec)
        spec[:fields].each_with_object({channel: message.channel}) do |(target, source), attributes|
          attributes[target] = field_value(message, source)
        end
      end

      def field_value(message, source)
        return message.public_send(source) unless source.is_a?(Array)

        field, scale = source
        scaled_value(message.public_send(field), scale)
      end

      def scaled_value(value, scale)
        scale ? send(scale, value) : value
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
        :downgrade_channel_voice64, :upgrade_attributes, :downgrade_attributes,
        :field_value, :scaled_value, :type_from_word, :status_from_nibble,
        :validate_words!, :scale_7_to_16, :scale_16_to_7,
        :scale_7_to_32, :scale_32_to_7, :scale_14_to_32,
        :scale_32_to_14
    end
  end
end
