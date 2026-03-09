# frozen_string_literal: true

module Webmidi
  module Middleware
    class VelocityScale < Base
      def initialize(app, factor: 1.0, min: 0, max: 127, curve: :linear, **options)
        super(app, **options)
        @factor = factor
        @min = min
        @max = max
        @curve = curve
      end

      def call(message)
        if velocity_message?(message)
          scaled = apply_curve(message.velocity)
          scaled_msg = message.class.new(
            **message.deconstruct_keys(nil).merge(velocity: scaled)
          )
          @app.call(scaled_msg)
        else
          @app.call(message)
        end
      end

      private

      def velocity_message?(msg)
        msg.is_a?(Message::Channel::NoteOn) || msg.is_a?(Message::Channel::NoteOff)
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
                 else
                   normalized * @factor
                 end
        (result * 127).round.clamp(@min, @max)
      end
    end
  end
end
