# frozen_string_literal: true

module Webmidi
  module Middleware
    class Transpose < Base
      def initialize(app, semitones: 0, **options)
        super(app, **options)
        @semitones = semitones
      end

      def call(message)
        if note_message?(message)
          new_note = (message.note + @semitones).clamp(0, 127)
          transposed = message.class.new(
            **message.deconstruct_keys(nil).merge(note: new_note)
          )
          @app.call(transposed)
        else
          @app.call(message)
        end
      end

      private

      def note_message?(msg)
        msg.is_a?(Message::Channel::NoteOn) ||
          msg.is_a?(Message::Channel::NoteOff) ||
          msg.is_a?(Message::Channel::PolyphonicPressure)
      end
    end
  end
end
