# frozen_string_literal: true

module Webmidi
  module Middleware
    class Pipeline
      def initialize(input, stack = nil)
        @input = input
        @stack = stack || Stack.new
      end

      def to(output)
        @input.on_message do |message|
          processed = @stack.call(message)
          output.send(processed) if processed
        end
      end
    end
  end
end
