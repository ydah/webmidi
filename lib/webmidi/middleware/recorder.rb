# frozen_string_literal: true

module Webmidi
  module Middleware
    class Recorder < Base
      attr_reader :tape

      def initialize(app = nil, **options)
        super(app || ->(msg) { msg }, **options)
        @tape = Tape.new
        @recording = false
        @mutex = Mutex.new
      end

      def call(message)
        tape = @mutex.synchronize { @recording ? @tape : nil }
        tape&.add(message)
        @app.call(message)
      end

      def record
        @mutex.synchronize do
          @tape = Tape.new
          @recording = true
        end
        if block_given?
          begin
            yield
          ensure
            @mutex.synchronize { @recording = false }
          end
        end
        @mutex.synchronize { @tape }
      end

      def stop
        @mutex.synchronize do
          @recording = false
          @tape
        end
      end

      def recording?
        @mutex.synchronize { @recording }
      end

      class Tape
        def initialize(entries: [], start_time: nil)
          @messages = entries.map(&:dup)
          @start_time = start_time
          @mutex = Mutex.new
        end

        def add(message)
          @mutex.synchronize do
            @start_time ||= message.timestamp
            @messages << { message: message, time: message.timestamp - @start_time }
          end
        end

        def messages
          snapshot.lazy.map { |entry| entry[:message] }
        end

        def message_count
          @mutex.synchronize { @messages.size }
        end

        def duration
          entries = snapshot
          return 0.0 if entries.empty?

          entries.last[:time]
        end

        def play(output, speed: 1.0)
          play_from(0.0, output, speed: speed)
        end

        def play_from(time, output, speed: 1.0)
          validate_speed!(speed)
          entries = snapshot.select { |e| e[:time] >= time }
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
          snapshot.select { |e| e[:time] >= target }.map { |e| e[:message] }
        end

        def slice(from, to)
          entries = snapshot.select { |e| e[:time] >= from && e[:time] <= to }.map do |entry|
            {
              message: entry[:message],
              time: entry[:time] - from
            }
          end
          Tape.new(entries: entries, start_time: 0.0)
        end

        private

        def snapshot
          @mutex.synchronize { @messages.map(&:dup) }
        end

        def validate_speed!(speed)
          return if speed.is_a?(Numeric) && speed.positive?

          raise InvalidMessageError, "Playback speed must be positive, got #{speed.inspect}"
        end
      end
    end
  end
end
