# frozen_string_literal: true

module Webmidi
  module Middleware
    class Base
      def initialize(app, **options)
        @app = app
        @options = options
      end

      def call(message)
        @app.call(message)
      end
    end
  end
end
