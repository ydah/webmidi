# frozen_string_literal: true

module Webmidi
  module Middleware
    class NoteRangeFilter < Base
      def initialize(app, min: 0, max: 127, **options)
        super(app, **options)
        validate_note!(min, "min")
        validate_note!(max, "max")
        raise InvalidMessageError, "min cannot be greater than max" if min > max

        @range = min..max
      end

      def call(message)
        return nil if note_message?(message) && !@range.cover?(message.note)

        @app.call(message)
      end

      private

      def note_message?(message)
        message.respond_to?(:note)
      end

      def validate_note!(note, name)
        return if note.is_a?(Integer) && note.between?(0, 127)

        raise InvalidMessageError, "#{name} must be between 0 and 127, got #{note.inspect}"
      end
    end
  end
end
