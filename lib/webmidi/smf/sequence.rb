# frozen_string_literal: true

module Webmidi
  module SMF
    class Sequence
      include Enumerable

      attr_accessor :format, :ppqn

      def initialize(format: 1, ppqn: 480)
        @format = format
        @ppqn = ppqn
        @tracks = []
      end

      def tracks
        @tracks.dup
      end

      def add_track(track)
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

        tempo_map = build_tempo_map
        max_ticks = @tracks.map { |t| t.events.sum(&:delta_time) }.max || 0
        ticks_to_seconds(max_ticks, tempo_map)
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

      def to_binary
        Writer.to_binary(self)
      end

      private

      def build_tempo_map
        tempo_events = []
        @tracks.each do |track|
          tick = 0
          track.each do |event|
            tick += event.delta_time
            if event.is_a?(MetaEvent) && event.type == MetaEvent::META_TYPES[:tempo]
              tempo_events << { tick: tick, tempo: event.tempo }
            end
          end
        end
        tempo_events.sort_by { |e| e[:tick] }
        tempo_events.unshift({ tick: 0, tempo: 500_000 }) if tempo_events.empty? || tempo_events.first[:tick] != 0
        tempo_events
      end

      def ticks_to_seconds(ticks, tempo_map)
        seconds = 0.0
        current_tick = 0

        tempo_map.each_with_index do |entry, i|
          next_tick = if i + 1 < tempo_map.size
                        [tempo_map[i + 1][:tick], ticks].min
                      else
                        ticks
                      end

          break if current_tick >= ticks

          delta = next_tick - current_tick
          seconds += (delta.to_f / @ppqn) * (entry[:tempo] / 1_000_000.0)
          current_tick = next_tick
        end

        seconds
      end
    end
  end
end
