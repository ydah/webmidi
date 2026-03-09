# frozen_string_literal: true

module Webmidi
  module SMF
    class Event
      attr_reader :delta_time, :absolute_time

      def initialize(delta_time: 0, absolute_time: 0)
        @delta_time = delta_time
        @absolute_time = absolute_time
      end

      def absolute_time=(time)
        @absolute_time = time
      end

      def delta_time=(time)
        @delta_time = time
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
        @type = type
        @data = data.frozen? ? data : data.dup.freeze
      end

      def text
        return nil unless text_event?

        @data.pack("C*").force_encoding("UTF-8")
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
        microseconds = (60_000_000.0 / bpm).round
        data = [
          (microseconds >> 16) & 0xFF,
          (microseconds >> 8) & 0xFF,
          microseconds & 0xFF
        ]
        new(type: META_TYPES[:tempo], data: data, **kwargs)
      end

      def self.track_name(name, **kwargs)
        new(type: META_TYPES[:track_name], data: name.encode("UTF-8").bytes, **kwargs)
      end

      def self.end_of_track(**kwargs)
        new(type: META_TYPES[:end_of_track], data: [], **kwargs)
      end

      def self.time_signature(numerator: 4, denominator: 4, clocks_per_click: 24, notes_per_quarter: 8, **kwargs)
        dd = Math.log2(denominator).to_i
        new(type: META_TYPES[:time_signature], data: [numerator, dd, clocks_per_click, notes_per_quarter], **kwargs)
      end

      def self.key_signature(key: 0, scale: 0, **kwargs)
        sf = key < 0 ? (256 + key) : key
        new(type: META_TYPES[:key_signature], data: [sf, scale], **kwargs)
      end
    end

    class SysExEvent < Event
      attr_reader :data

      def initialize(data:, **kwargs)
        super(**kwargs)
        @data = data.frozen? ? data : data.dup.freeze
      end

      def to_bytes
        [0xF0, *@data, 0xF7]
      end
    end
  end
end
