# frozen_string_literal: true

module Webmidi
  module Middleware
    class Recorder < Base
      attr_reader :tape

      def initialize(app = nil, **options)
        super(app || ->(msg) { msg }, **options)
        @tape = Tape.new
        @recording = false
      end

      def call(message)
        @tape.add(message) if @recording
        @app.call(message)
      end

      def record
        @tape = Tape.new
        @recording = true
        if block_given?
          yield
          @recording = false
        end
        @tape
      end

      def stop
        @recording = false
        @tape
      end

      def recording?
        @recording
      end

      class Tape
        def initialize
          @messages = []
          @start_time = nil
        end

        def add(message)
          @start_time ||= message.timestamp
          @messages << { message: message, time: message.timestamp - @start_time }
        end

        def messages
          @messages.lazy.map { |entry| entry[:message] }
        end

        def message_count
          @messages.size
        end

        def duration
          return 0.0 if @messages.empty?

          @messages.last[:time]
        end

        def play(output, speed: 1.0)
          play_from(0.0, output, speed: speed)
        end

        def play_from(time, output, speed: 1.0)
          entries = @messages.select { |e| e[:time] >= time }
          last_time = time

          entries.each do |entry|
            delay = (entry[:time] - last_time) / speed
            sleep(delay) if delay > 0.001
            output.send(entry[:message])
            last_time = entry[:time]
          end
        end

        def rewind(seconds)
          target = duration - seconds
          target = 0.0 if target < 0
          @messages.select { |e| e[:time] >= target }.map { |e| e[:message] }
        end

        def slice(from, to)
          new_tape = Tape.new
          @messages.select { |e| e[:time] >= from && e[:time] <= to }.each do |entry|
            new_tape.instance_variable_get(:@messages) << {
              message: entry[:message],
              time: entry[:time] - from
            }
          end
          new_tape.instance_variable_set(:@start_time, 0.0)
          new_tape
        end
      end
    end
  end
end
