# frozen_string_literal: true

module Webmidi
  module Music
    module Rhythm
      DURATIONS = {
        whole: 4.0,
        half: 2.0,
        quarter: 1.0,
        eighth: 0.5,
        sixteenth: 0.25,
        thirty_second: 0.125,
        dotted_whole: 6.0,
        dotted_half: 3.0,
        dotted_quarter: 1.5,
        dotted_eighth: 0.75,
        triplet_quarter: 2.0 / 3.0,
        triplet_eighth: 1.0 / 3.0,
        triplet_sixteenth: 1.0 / 6.0
      }.freeze

      module_function

      def duration_in_beats(name)
        DURATIONS[name] || raise(InvalidMessageError, "Unknown duration: #{name}")
      end

      def duration_in_ticks(name, ppqn: 480)
        validate_ppqn!(ppqn)
        (duration_in_beats(name) * ppqn).round
      end

      def duration_in_seconds(name, bpm: 120)
        validate_bpm!(bpm)
        duration_in_beats(name) * (60.0 / bpm)
      end

      def beats_to_ticks(beats, ppqn: 480)
        validate_beats!(beats)
        validate_ppqn!(ppqn)
        (beats * ppqn).round
      end

      def ticks_to_beats(ticks, ppqn: 480)
        validate_ticks!(ticks)
        validate_ppqn!(ppqn)
        ticks.to_f / ppqn
      end

      def dotted(name, dots: 1)
        raise InvalidMessageError, "dots must be a non-negative integer" unless dots.is_a?(Integer) && dots >= 0

        base = duration_in_beats(name)
        dots.times.reduce(base) { |sum, index| sum + (base / (2**(index + 1))) }
      end

      def tuplet(name, in_time_of:, notes:)
        unless in_time_of.is_a?(Integer) && in_time_of.positive? && notes.is_a?(Integer) && notes.positive?
          raise InvalidMessageError, "Tuplet values must be positive integers"
        end

        duration_in_beats(name) * (in_time_of.to_f / notes)
      end

      def validate_ppqn!(ppqn)
        return if ppqn.is_a?(Integer) && ppqn.positive?

        raise InvalidMessageError, "PPQN must be positive, got #{ppqn.inspect}"
      end

      def validate_bpm!(bpm)
        return if bpm.is_a?(Numeric) && bpm.positive?

        raise InvalidMessageError, "BPM must be positive, got #{bpm.inspect}"
      end

      def validate_beats!(beats)
        return if beats.is_a?(Numeric) && beats >= 0

        raise InvalidMessageError, "Beats must be non-negative, got #{beats.inspect}"
      end

      def validate_ticks!(ticks)
        return if ticks.is_a?(Numeric) && ticks >= 0

        raise InvalidMessageError, "Ticks must be non-negative, got #{ticks.inspect}"
      end

      private_class_method :validate_ppqn!, :validate_bpm!, :validate_beats!, :validate_ticks!
    end
  end
end
