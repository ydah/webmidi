# frozen_string_literal: true

module Webmidi
  module SMF
    class Sequence
      include Enumerable

      attr_reader :format, :ppqn

      def initialize(format: 1, ppqn: 480)
        @tracks = []
        self.format = format
        self.ppqn = ppqn
      end

      def tracks
        @tracks.dup
      end

      def add_track(track)
        if @format == 0 && @tracks.any?
          raise InvalidSMFError, "SMF format 0 supports exactly one track"
        end

        @tracks << track
        self
      end

      def [](index)
        @tracks[index]
      end

      def each(&block)
        @tracks.each(&block)
      end

      def size
        @tracks.size
      end

      def duration
        return 0.0 if @tracks.empty?

        tempo_map = tempo_map()
        max_ticks = @tracks.map { |t| t.events.sum(&:delta_time) }.max || 0
        tempo_map.ticks_to_seconds(max_ticks)
      end

      def format=(format)
        unless [0, 1].include?(format)
          raise UnsupportedFormatError, "Only SMF format 0 and 1 are supported, got #{format.inspect}"
        end
        if format.zero? && defined?(@tracks) && @tracks.size > 1
          raise InvalidSMFError, "Cannot set format 0 on a sequence with multiple tracks"
        end

        @format = format
      end

      def ppqn=(ppqn)
        unless ppqn.is_a?(Integer) && ppqn.between?(1, 0x7FFF)
          raise InvalidSMFError, "PPQN must be between 1 and 32767, got #{ppqn.inspect}"
        end

        @ppqn = ppqn
      end

      def tempo_map
        TempoMap.from_sequence(self)
      end

      def to_format0
        sequence = self.class.new(format: 0, ppqn: @ppqn)
        merged = Track.new
        events_with_time = @tracks.flat_map do |track|
          absolute = 0
          track.events.map do |event|
            absolute += event.delta_time
            [absolute, event]
          end
        end.sort_by(&:first)

        previous = 0
        events_with_time.each do |absolute, event|
          merged << duplicate_event(event, delta_time: absolute - previous, absolute_time: absolute)
          previous = absolute
        end
        sequence.add_track(merged)
      end

      def to_format1
        sequence = self.class.new(format: 1, ppqn: @ppqn)
        @tracks.each do |track|
          copy = Track.new(name: track.name, channel: track.channel)
          track.each do |event|
            copy << duplicate_event(event, delta_time: event.delta_time, absolute_time: event.absolute_time)
          end
          sequence.add_track(copy)
        end
        sequence
      end

      def self.read(path_or_io)
        Reader.read(path_or_io)
      end

      def self.parse(binary)
        Reader.parse(binary)
      end

      def write(path_or_io)
        Writer.write(self, path_or_io)
      end

      def to_binary(**options)
        Writer.to_binary(self, **options)
      end

      private

      def duplicate_event(event, delta_time:, absolute_time:)
        case event
        when MIDIEvent
          MIDIEvent.new(message: event.message, delta_time: delta_time, absolute_time: absolute_time)
        when MetaEvent
          MetaEvent.new(type: event.type, data: event.data, delta_time: delta_time, absolute_time: absolute_time)
        when SysExEvent
          SysExEvent.new(data: event.data, delta_time: delta_time, absolute_time: absolute_time)
        else
          raise InvalidSMFError, "Unknown SMF event type: #{event.class}"
        end
      end
    end
  end
end
