# frozen_string_literal: true

module Webmidi
  module Music
    module Chord
      TYPES = {
        major: [0, 4, 7],
        minor: [0, 3, 7],
        dim: [0, 3, 6],
        aug: [0, 4, 8],
        sus2: [0, 2, 7],
        sus4: [0, 5, 7],
        dom7: [0, 4, 7, 10],
        maj7: [0, 4, 7, 11],
        min7: [0, 3, 7, 10],
        dim7: [0, 3, 6, 9],
        half_dim7: [0, 3, 6, 10],
        aug7: [0, 4, 8, 10],
        min_maj7: [0, 3, 7, 11],
        dom9: [0, 4, 7, 10, 14],
        maj9: [0, 4, 7, 11, 14],
        min9: [0, 3, 7, 10, 14],
        dom11: [0, 4, 7, 10, 14, 17],
        dom13: [0, 4, 7, 10, 14, 17, 21],
        add9: [0, 4, 7, 14],
        six: [0, 4, 7, 9],
        min6: [0, 3, 7, 9],
        power: [0, 7]
      }.freeze

      @custom_types = {}

      module_function

      def build(root, type = :major, inversion: 0, range: :strict)
        validate_inversion!(inversion)
        root_midi = Note.to_midi(root)
        intervals = TYPES[type] || @custom_types[type]
        raise InvalidMessageError, "Unknown chord type: #{type}" unless intervals

        notes = intervals.map { |i| root_midi + i }

        inversion.times do
          notes.push(notes.shift + 12)
        end

        apply_range_policy(notes, range)
      end

      def define(name, intervals = nil, &block)
        intervals = block.call(0) if block
        validate_intervals!(intervals)
        @custom_types[name] = intervals.dup.freeze
        self
      end

      def types
        TYPES.keys + @custom_types.keys
      end

      def validate_inversion!(inversion)
        return if inversion.is_a?(Integer) && inversion >= 0

        raise InvalidMessageError, "Chord inversion must be a non-negative integer, got #{inversion.inspect}"
      end

      def validate_intervals!(intervals)
        unless intervals.respond_to?(:each) && intervals.all? { |interval| interval.is_a?(Integer) }
          raise InvalidMessageError, "Chord intervals must be integers"
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

      private_class_method :validate_inversion!, :validate_intervals!, :apply_range_policy
    end
  end
end
