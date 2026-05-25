# frozen_string_literal: true

module Webmidi
  module Music
    module Note
      NOTE_NAMES = {
        "C" => 0, "D" => 2, "E" => 4, "F" => 5,
        "G" => 7, "A" => 9, "B" => 11
      }.freeze

      MIDI_TO_NAME = %w[C Cs D Ds E F Fs G Gs A As B].freeze
      MIDI_RANGE = 0..127

      module_function

      def to_midi(input, validate: true)
        midi = case input
        when Integer
          input
        when Symbol
          parse_note_name(input.to_s)
        when String
          parse_note_name(input)
        else
          raise InvalidMessageError, "Cannot convert #{input.class} to MIDI note"
        end
        validate_midi!(midi) if validate
        midi
      end

      def to_name(midi_number, sharps: true)
        validate_midi!(midi_number)
        octave = (midi_number / 12) - 1
        note_index = midi_number % 12
        name = if sharps
          MIDI_TO_NAME[note_index]
        else
          %w[C Db D Eb E F Gb G Ab A Bb B][note_index]
        end
        "#{name}#{octave}"
      end

      def to_frequency(midi_number, a4: 440.0)
        validate_midi!(midi_number)
        validate_frequency_reference!(a4)
        a4 * (2.0**((midi_number - 69) / 12.0))
      end

      def from_frequency(freq, a4: 440.0)
        validate_frequency!(freq)
        validate_frequency_reference!(a4)
        (12 * Math.log2(freq / a4) + 69).round
      end

      def parse_note_name(str)
        match = str.match(/\A([A-Ga-g])(ss|\#\#|s|\#|bb|b)?(-?\d+)\z/)
        raise InvalidMessageError, "Invalid note name: #{str}" unless match

        name = match[1].upcase
        accidental = match[2]
        octave = match[3].to_i

        base = NOTE_NAMES[name]
        raise InvalidMessageError, "Unknown note: #{name}" unless base

        midi = base + ((octave + 1) * 12)
        case accidental
        when "s", "#"
          midi += 1
        when "ss", "##"
          midi += 2
        when "b"
          midi -= 1
        when "bb"
          midi -= 2
        end

        midi
      end

      def validate_midi!(midi_number)
        return if midi_number.is_a?(Integer) && MIDI_RANGE.cover?(midi_number)

        raise InvalidMessageError, "MIDI note must be between 0 and 127, got #{midi_number.inspect}"
      end

      def validate_frequency!(freq)
        return if freq.is_a?(Numeric) && freq.positive?

        raise InvalidMessageError, "Frequency must be positive, got #{freq.inspect}"
      end

      def validate_frequency_reference!(a4)
        return if a4.is_a?(Numeric) && a4.positive?

        raise InvalidMessageError, "A4 reference frequency must be positive, got #{a4.inspect}"
      end

      private_class_method :parse_note_name, :validate_frequency!, :validate_frequency_reference!
    end
  end
end
