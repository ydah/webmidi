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

      def build(root, type = :major, inversion: 0)
        root_midi = Note.to_midi(root)
        intervals = TYPES[type] || @custom_types[type]
        raise InvalidMessageError, "Unknown chord type: #{type}" unless intervals

        notes = intervals.map { |i| root_midi + i }

        inversion.times do
          notes.push(notes.shift + 12)
        end

        notes
      end

      def define(name, &block)
        @custom_types[name] = block.call(0)
      end

      def types
        TYPES.keys + @custom_types.keys
      end
    end
  end
end
