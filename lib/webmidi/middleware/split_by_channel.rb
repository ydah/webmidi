# frozen_string_literal: true

module Webmidi
  module Middleware
    class SplitByChannel < Base
      SYSTEM_ROUTE = :system

      def initialize(app, routes:, passthrough: false, **options)
        super(app, **options)
        @routes = normalize_routes(routes)
        @passthrough = passthrough
      end

      def call(message)
        targets = @routes[route_key(message)]
        return @app.call(message) unless targets

        targets.each { |target| deliver(target, message) }
        return @app.call(message) if @passthrough

        nil
      end

      private

      def route_key(message)
        message.channel || SYSTEM_ROUTE
      end

      def normalize_routes(routes)
        unless routes.respond_to?(:each)
          raise InvalidMessageError, "routes must be enumerable, got #{routes.class}"
        end

        routes.each_with_object({}) do |(channel, targets), result|
          key = normalize_route_key(channel)
          result[key] = Array(targets).tap { |list| list.each { |target| validate_target!(target) } }
        end
      end

      def normalize_route_key(channel)
        return SYSTEM_ROUTE if channel == SYSTEM_ROUTE

        unless channel.is_a?(Integer) && channel.between?(0, 15)
          raise InvalidMessageError, "Route channel must be between 0 and 15, got #{channel.inspect}"
        end

        channel
      end

      def validate_target!(target)
        return if target.respond_to?(:call) || target.respond_to?(:<<)

        raise InvalidMessageError, "Route target must respond to call or <<, got #{target.class}"
      end

      def deliver(target, message)
        if target.respond_to?(:call)
          target.call(message)
        else
          target << message
        end
      end
    end
  end
end
