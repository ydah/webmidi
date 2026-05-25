# frozen_string_literal: true

module Webmidi
  module SMF
    class TempoMap
      DEFAULT_TEMPO = 500_000

      attr_reader :entries, :ppqn

      def self.from_sequence(sequence)
        tempo_events = []
        sequence.each do |track|
          tick = 0
          track.each do |event|
            tick += event.delta_time
            if event.is_a?(MetaEvent) && event.type == MetaEvent::META_TYPES[:tempo]
              tempo_events << {tick: tick, tempo: event.tempo}
            end
          end
        end
        new(tempo_events, ppqn: sequence.ppqn)
      end

      def initialize(entries = [], ppqn:)
        raise InvalidSMFError, "PPQN must be positive" unless ppqn.is_a?(Integer) && ppqn.positive?

        @ppqn = ppqn
        @entries = entries.map { |entry| normalize_entry(entry) }.sort_by { |entry| entry[:tick] }
        @entries.unshift({tick: 0, tempo: DEFAULT_TEMPO}) if @entries.empty? || @entries.first[:tick] != 0
        freeze_entries!
      end

      def ticks_to_seconds(ticks)
        validate_non_negative_number!(ticks, "Ticks")
        seconds = 0.0
        current_tick = 0

        @entries.each_with_index do |entry, index|
          next_tick = if index + 1 < @entries.size
            [@entries[index + 1][:tick], ticks].min
          else
            ticks
          end
          break if current_tick >= ticks

          seconds += ticks_segment_to_seconds(next_tick - current_tick, entry[:tempo])
          current_tick = next_tick
        end

        seconds
      end

      def seconds_to_ticks(seconds)
        validate_non_negative_number!(seconds, "Seconds")
        remaining = seconds.to_f
        current_tick = 0

        @entries.each_with_index do |entry, index|
          next_tick = (index + 1 < @entries.size) ? @entries[index + 1][:tick] : nil
          segment_ticks = next_tick ? next_tick - current_tick : nil
          seconds_per_tick = entry[:tempo] / 1_000_000.0 / @ppqn

          if segment_ticks.nil?
            return current_tick + (remaining / seconds_per_tick).round
          end

          segment_seconds = segment_ticks * seconds_per_tick
          return current_tick + (remaining / seconds_per_tick).round if remaining <= segment_seconds

          remaining -= segment_seconds
          current_tick = next_tick
        end
      end

      def tempo_at(ticks)
        validate_non_negative_number!(ticks, "Ticks")
        @entries.rfind { |entry| entry[:tick] <= ticks }[:tempo]
      end

      private

      def normalize_entry(entry)
        tick = entry.fetch(:tick)
        tempo = entry.fetch(:tempo)
        raise InvalidSMFError, "Tempo map tick must be non-negative" unless tick.is_a?(Integer) && tick >= 0
        raise InvalidSMFError, "Tempo must be positive" unless tempo.is_a?(Integer) && tempo.positive?

        {tick: tick, tempo: tempo}
      end

      def freeze_entries!
        @entries.each(&:freeze)
        @entries.freeze
      end

      def ticks_segment_to_seconds(ticks, tempo)
        (ticks.to_f / @ppqn) * (tempo / 1_000_000.0)
      end

      def validate_non_negative_number!(value, name)
        return if value.is_a?(Numeric) && value >= 0

        raise InvalidSMFError, "#{name} must be non-negative, got #{value.inspect}"
      end
    end
  end
end
