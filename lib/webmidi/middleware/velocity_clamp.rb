# frozen_string_literal: true

module Webmidi
  module Middleware
    class VelocityClamp < Base
      def initialize(app, min: 0, max: 127, include_note_off: true, **options)
        super(app, **options)
        validate_velocity!(min, "min")
        validate_velocity!(max, "max")
        raise InvalidMessageError, "min cannot be greater than max" if min > max

        @min = min
        @max = max
        @include_note_off = include_note_off
      end

      def call(message)
        return @app.call(message) unless velocity_message?(message)

        @app.call(message.with(velocity: message.velocity.clamp(@min, @max)))
      end

      private

      def velocity_message?(message)
        message.is_a?(Message::Channel::NoteOn) ||
          (@include_note_off && message.is_a?(Message::Channel::NoteOff))
      end

      def validate_velocity!(velocity, name)
        return if velocity.is_a?(Integer) && velocity.between?(0, 127)

        raise InvalidMessageError, "#{name} must be between 0 and 127, got #{velocity.inspect}"
      end
    end
  end
end
