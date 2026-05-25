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

      def build(root, type = :major, range: :strict)
        root_midi = Note.to_midi(root)
        intervals = TYPES[type] || @custom_types[type]
        raise InvalidMessageError, "Unknown scale type: #{type}" unless intervals

        apply_range_policy(intervals.map { |i| root_midi + i }, range)
      end

      def define(name, intervals)
        validate_intervals!(intervals)
        @custom_types[name] = intervals
        self
      end

      def types
        TYPES.keys + @custom_types.keys
      end

      def degree(root, type, degree_num)
        unless degree_num.is_a?(Integer) && degree_num.positive?
          raise InvalidMessageError, "Scale degree must be a positive integer, got #{degree_num.inspect}"
        end

        root_midi = Note.to_midi(root)
        intervals = TYPES[type] || @custom_types[type]
        raise InvalidMessageError, "Unknown scale type: #{type}" unless intervals

        index = (degree_num - 1) % intervals.size
        octave = (degree_num - 1) / intervals.size
        note = root_midi + intervals[index] + (octave * 12)
        Note.validate_midi!(note)
        note
      end

      def validate_intervals!(intervals)
        unless intervals.respond_to?(:each) && intervals.all? { |interval| interval.is_a?(Integer) }
          raise InvalidMessageError, "Scale intervals must be integers"
        end
      end

      def apply_range_policy(notes, range)
        case range
        when :strict
          notes.each { |note| Note.validate_midi!(note) }
          notes
        when :clamp
          notes.map { |note| note.clamp(0, 127) }
        when :allow_out_of_range
          notes
        else
          raise InvalidMessageError, "Unknown range policy: #{range.inspect}"
        end
      end

      private_class_method :validate_intervals!, :apply_range_policy
    end
  end
end
