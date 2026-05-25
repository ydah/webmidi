# frozen_string_literal: true

module Webmidi
  module Middleware
    class ChannelMap < Base
      def initialize(app, map: nil, from: nil, to: nil, **options)
        super(app, **options)
        @map = normalize_map(map, from, to)
      end

      def call(message)
        return @app.call(message) unless message.channel

        target = @map.fetch(message.channel, message.channel)
        @app.call(message.with(channel: target))
      end

      private

      def normalize_map(map, from, to)
        mapping = map || ((from.nil? || to.nil?) ? {} : {from => to})
        mapping.each_with_object({}) do |(source, target), result|
          validate_channel!(source, "source channel")
          validate_channel!(target, "target channel")
          result[source] = target
        end
      end

      def validate_channel!(channel, name)
        return if channel.is_a?(Integer) && channel.between?(0, 15)

        raise InvalidMessageError, "#{name} must be between 0 and 15, got #{channel.inspect}"
      end
    end
  end
end
