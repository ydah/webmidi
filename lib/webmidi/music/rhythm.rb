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
        (duration_in_beats(name) * ppqn).round
      end

      def duration_in_seconds(name, bpm: 120)
        duration_in_beats(name) * (60.0 / bpm)
      end

      def beats_to_ticks(beats, ppqn: 480)
        (beats * ppqn).round
      end

      def ticks_to_beats(ticks, ppqn: 480)
        ticks.to_f / ppqn
      end
    end
  end
end
