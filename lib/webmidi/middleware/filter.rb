# frozen_string_literal: true

module Webmidi
  module Middleware
    class Filter < Base
      def initialize(app, channels: nil, types: nil, include_system: true, **options)
        super(app, **options)
        @channels = channels
        @types = types
        @include_system = include_system
      end

      def call(message)
        return nil if @channels && !message.channel && !@include_system
        return nil if @channels && message.channel && !@channels.include?(message.channel)
        return nil if @types && !@types.any? { |t| message.is_a?(t) }

        @app.call(message)
      end
    end
  end
end
