# frozen_string_literal: true

module Webmidi
  module Middleware
    class Debounce < Base
      def initialize(app, interval:, key: nil, **options)
        super(app, **options)
        validate_interval!(interval)
        @interval = interval
        @key = key || ->(message) { message.to_bytes }
        @last_seen = {}
      end

      def call(message)
        key = @key.call(message)
        now = message.timestamp
        last = @last_seen[key]
        return nil if last && (now - last) < @interval

        @last_seen[key] = now
        @app.call(message)
      end

      private

      def validate_interval!(interval)
        return if interval.is_a?(Numeric) && interval.positive?

        raise InvalidMessageError, "interval must be positive, got #{interval.inspect}"
      end
    end

    class Throttle < Base
      def initialize(app, interval:, **options)
        super(app, **options)
        validate_interval!(interval)
        @interval = interval
        @last_sent = nil
      end

      def call(message)
        now = message.timestamp
        return nil if @last_sent && (now - @last_sent) < @interval

        @last_sent = now
        @app.call(message)
      end

      private

      def validate_interval!(interval)
        return if interval.is_a?(Numeric) && interval.positive?

        raise InvalidMessageError, "interval must be positive, got #{interval.inspect}"
      end
    end
  end
end
