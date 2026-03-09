# frozen_string_literal: true

module Webmidi
  module Music
    module Scale
      TYPES = {
        major: [0, 2, 4, 5, 7, 9, 11],
        minor: [0, 2, 3, 5, 7, 8, 10],
        harmonic_minor: [0, 2, 3, 5, 7, 8, 11],
        melodic_minor: [0, 2, 3, 5, 7, 9, 11],
        dorian: [0, 2, 3, 5, 7, 9, 10],
        phrygian: [0, 1, 3, 5, 7, 8, 10],
        lydian: [0, 2, 4, 6, 7, 9, 11],
        mixolydian: [0, 2, 4, 5, 7, 9, 10],
        locrian: [0, 1, 3, 5, 6, 8, 10],
        pentatonic: [0, 2, 4, 7, 9],
        minor_pentatonic: [0, 3, 5, 7, 10],
        blues: [0, 3, 5, 6, 7, 10],
        chromatic: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        whole_tone: [0, 2, 4, 6, 8, 10],
        diminished: [0, 2, 3, 5, 6, 8, 9, 11]
      }.freeze

      @custom_types = {}

      module_function

      def build(root, type = :major)
        root_midi = Note.to_midi(root)
        intervals = TYPES[type] || @custom_types[type]
        raise InvalidMessageError, "Unknown scale type: #{type}" unless intervals

        intervals.map { |i| root_midi + i }
      end

      def define(name, intervals)
        @custom_types[name] = intervals
      end

      def types
        TYPES.keys + @custom_types.keys
      end

      def degree(root, type, degree_num)
        notes = build(root, type)
        notes[(degree_num - 1) % notes.size]
      end
    end
  end
end
