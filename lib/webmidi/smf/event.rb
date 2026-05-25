# frozen_string_literal: true

module Webmidi
  module SMF
    class Event
      attr_reader :delta_time, :absolute_time

      def initialize(delta_time: 0, absolute_time: 0)
        validate_time!(delta_time, "Delta time")
        validate_time!(absolute_time, "Absolute time")
        @delta_time = delta_time
        @absolute_time = absolute_time
      end

      def absolute_time=(time)
        validate_time!(time, "Absolute time")
        @absolute_time = time
      end

      def delta_time=(time)
        validate_time!(time, "Delta time")
        @delta_time = time
      end

      private

      def validate_time!(time, name)
        return if time.is_a?(Integer) && time >= 0

        raise InvalidSMFError, "#{name} must be a non-negative integer, got #{time.inspect}"
      end
    end

    class MIDIEvent < Event
      attr_reader :message

      def initialize(message:, **kwargs)
        super(**kwargs)
        @message = message
      end

      def to_bytes
        @message.to_bytes
      end
    end

    class MetaEvent < Event
      attr_reader :type, :data

      META_TYPES = {
        sequence_number: 0x00,
        text: 0x01,
        copyright: 0x02,
        track_name: 0x03,
        instrument_name: 0x04,
        lyric: 0x05,
        marker: 0x06,
        cue_point: 0x07,
        channel_prefix: 0x20,
        end_of_track: 0x2F,
        tempo: 0x51,
        smpte_offset: 0x54,
        time_signature: 0x58,
        key_signature: 0x59,
        sequencer_specific: 0x7F
      }.freeze

      def initialize(type:, data: [], **kwargs)
        super(**kwargs)
        validate_type!(type)
        validate_data!(data)
        @type = type
        @data = data.frozen? ? data : data.dup.freeze
      end

      def text(encoding: Encoding::UTF_8)
        return nil unless text_event?

        @data.pack("C*").force_encoding(encoding)
      end

      def text_event?
        @type.between?(0x01, 0x07)
      end

      def tempo
        return nil unless @type == META_TYPES[:tempo]
        return nil unless @data.size == 3

        (@data[0] << 16) | (@data[1] << 8) | @data[2]
      end

      def bpm
        t = tempo
        return nil unless t

        60_000_000.0 / t
      end

      def self.tempo(bpm, **kwargs)
        raise InvalidSMFError, "Tempo BPM must be positive, got #{bpm.inspect}" unless bpm.is_a?(Numeric) && bpm.positive?

        microseconds = (60_000_000.0 / bpm).round
        data = [
          (microseconds >> 16) & 0xFF,
          (microseconds >> 8) & 0xFF,
          microseconds & 0xFF
        ]
        new(type: META_TYPES[:tempo], data: data, **kwargs)
      end

      def self.text(value, type: :text, encoding: Encoding::UTF_8, **kwargs)
        meta_type = type.is_a?(Symbol) ? META_TYPES.fetch(type) : type
        new(type: meta_type, data: value.encode(encoding).bytes, **kwargs)
      end

      def self.track_name(name, encoding: Encoding::UTF_8, **kwargs)
        text(name, type: :track_name, encoding: encoding, **kwargs)
      end

      def self.end_of_track(**kwargs)
        new(type: META_TYPES[:end_of_track], data: [], **kwargs)
      end

      def self.time_signature(numerator: 4, denominator: 4, clocks_per_click: 24, notes_per_quarter: 8, **kwargs)
        unless numerator.is_a?(Integer) && numerator.positive?
          raise InvalidSMFError, "Time signature numerator must be positive, got #{numerator.inspect}"
        end
        unless denominator.is_a?(Integer) && denominator.positive? && (denominator & (denominator - 1)).zero?
          raise InvalidSMFError, "Time signature denominator must be a power of two, got #{denominator.inspect}"
        end
        [clocks_per_click, notes_per_quarter].each do |value|
          raise InvalidSMFError, "Time signature values must be bytes" unless value.is_a?(Integer) && value.between?(0, 255)
        end

        dd = Math.log2(denominator).to_i
        new(type: META_TYPES[:time_signature], data: [numerator, dd, clocks_per_click, notes_per_quarter], **kwargs)
      end

      def self.key_signature(key: 0, scale: 0, **kwargs)
        raise InvalidSMFError, "Key signature must be between -7 and 7, got #{key.inspect}" unless key.is_a?(Integer) && key.between?(-7, 7)

        scale = case scale
        when :major then 0
        when :minor then 1
        else scale
        end
        raise InvalidSMFError, "Key signature scale must be 0/:major or 1/:minor" unless [0, 1].include?(scale)

        sf = (key < 0) ? (256 + key) : key
        new(type: META_TYPES[:key_signature], data: [sf, scale], **kwargs)
      end

      private

      def validate_type!(type)
        return if type.is_a?(Integer) && type.between?(0, 127)

        raise InvalidSMFError, "Meta event type must be between 0 and 127, got #{type.inspect}"
      end

      def validate_data!(data)
        unless data.respond_to?(:each)
          raise InvalidSMFError, "Meta event data must be enumerable, got #{data.class}"
        end

        data.each_with_index do |byte, index|
          next if byte.is_a?(Integer) && byte.between?(0, 255)

          raise InvalidSMFError, "Meta event data byte #{index} must be between 0 and 255, got #{byte.inspect}"
        end
      end
    end

    class SysExEvent < Event
      attr_reader :data

      def initialize(data:, **kwargs)
        super(**kwargs)
        bytes = normalize_data(data)
        @data = bytes.frozen? ? bytes : bytes.dup.freeze
      end

      def to_bytes
        (@data.last == 0xF7) ? [0xF0, *@data] : [0xF0, *@data, 0xF7]
      end

      private

      def normalize_data(data)
        unless data.respond_to?(:each)
          raise InvalidSMFError, "SysEx event data must be enumerable, got #{data.class}"
        end

        bytes = data.to_a
        bytes = bytes[1..] if bytes.first == 0xF0
        bytes.each_with_index do |byte, index|
          next if byte.is_a?(Integer) && byte.between?(0, 255)

          raise InvalidSMFError, "SysEx event data byte #{index} must be between 0 and 255, got #{byte.inspect}"
        end
        bytes
      end
    end
  end
end
