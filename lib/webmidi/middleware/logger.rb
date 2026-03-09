# frozen_string_literal: true

module Webmidi
  module Middleware
    class Logger < Base
      def initialize(app, output: $stderr, **options)
        super(app, **options)
        @output = output
      end

      def call(message)
        @output.puts "[MIDI] #{message.class.name.split("::").last}: #{message.to_hex}"
        @app.call(message)
      end
    end
  end
end
