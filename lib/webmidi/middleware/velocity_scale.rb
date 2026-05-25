# frozen_string_literal: true

module Webmidi
  module Middleware
    class VelocityScale < Base
      def initialize(app, factor: 1.0, min: 0, max: 127, curve: :linear, **options)
        super(app, **options)
        validate_options!(factor, min, max, curve)
        @factor = factor
        @min = min
        @max = max
        @curve = curve
        @include_note_off = options.fetch(:include_note_off, true)
      end

      def call(message)
        if velocity_message?(message)
          scaled = apply_curve(message.velocity)
          scaled_msg = message.with(velocity: scaled)
          @app.call(scaled_msg)
        else
          @app.call(message)
        end
      end

      private

      def velocity_message?(msg)
        msg.is_a?(Message::Channel::NoteOn) || (@include_note_off && msg.is_a?(Message::Channel::NoteOff))
      end

      def apply_curve(velocity)
        normalized = velocity / 127.0
        result = case @curve
        when :linear
          normalized * @factor
        when :exponential
          (normalized**2) * @factor
        when :logarithmic
          Math.sqrt(normalized) * @factor
        end
        (result * 127).round.clamp(@min, @max)
      end

      def validate_options!(factor, min, max, curve)
        raise InvalidMessageError, "Velocity factor must be non-negative" unless factor.is_a?(Numeric) && factor >= 0
        unless min.is_a?(Integer) && min.between?(0, 127) && max.is_a?(Integer) && max.between?(0, 127)
          raise InvalidMessageError, "Velocity min/max must be MIDI data bytes"
        end
        raise InvalidMessageError, "Velocity min cannot be greater than max" if min > max
        raise InvalidMessageError, "Unknown velocity curve: #{curve.inspect}" unless %i[linear exponential logarithmic].include?(curve)
      end
    end
  end
end
