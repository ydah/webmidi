# frozen_string_literal: true

module Webmidi
  module Middleware
    class Stack
      def initialize(&block)
        @middlewares = []
        instance_eval(&block) if block
      end

      def use(middleware_class_or_proc, **options)
        @middlewares << [middleware_class_or_proc, options]
        self
      end

      def call(message)
        app = build
        app.call(message)
      end

      def build
        endpoint = ->(msg) { msg }
        @middlewares.reverse_each do |middleware, options|
          current_app = endpoint
          endpoint = if middleware.is_a?(Proc)
                       lambda_adapter(middleware, current_app)
                     else
                       middleware.new(current_app, **options)
                     end
        end
        endpoint
      end

      private

      def lambda_adapter(proc, app)
        LambdaMiddleware.new(app, proc)
      end

      class LambdaMiddleware
        def initialize(app, proc)
          @app = app
          @proc = proc
        end

        def call(message)
          @proc.call(message, @app)
        end
      end
    end
  end
end
