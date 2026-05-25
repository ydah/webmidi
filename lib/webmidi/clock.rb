# frozen_string_literal: true

require_relative "callback_subscription"

module Webmidi
  class Clock
    PPQN = 24

    attr_reader :bpm, :running

    alias_method :running?, :running

    def initialize(bpm: 120)
      validate_bpm!(bpm)
      @bpm = bpm
      @running = false
      @callbacks = []
      @error_callbacks = []
      @mutex = Mutex.new
      @thread = nil
      @tick_count = 0
    end

    def bpm=(new_bpm)
      validate_bpm!(new_bpm)
      @mutex.synchronize { @bpm = new_bpm }
    end

    def start
      @mutex.synchronize do
        return self if @running

        @running = true
        @tick_count = 0
        @thread = Thread.new { clock_loop }
      end
      self
    end

    def stop
      thread = @mutex.synchronize do
        @running = false
        @thread
      end
      thread&.join(1) if thread && thread != Thread.current
      @mutex.synchronize { @thread = nil if @thread == thread }
      self
    end

    def on_tick(&block)
      raise ArgumentError, "on_tick requires a block" unless block

      @mutex.synchronize { @callbacks << block }
      CallbackSubscription.new do
        @mutex.synchronize { @callbacks.delete(block) }
      end
    end

    def on_error(&block)
      raise ArgumentError, "on_error requires a block" unless block

      @mutex.synchronize { @error_callbacks << block }
      CallbackSubscription.new do
        @mutex.synchronize { @error_callbacks.delete(block) }
      end
    end

    def pipe_to(output)
      on_tick { output.send(Message.clock) }
    end

    def start_message
      Message.start
    end

    def stop_message
      Message.stop
    end

    def tick_count
      @mutex.synchronize { @tick_count }
    end

    def beat_count
      @mutex.synchronize { @tick_count / PPQN }
    end

    private

    def clock_loop
      next_tick = monotonic_now
      loop do
        running, interval = @mutex.synchronize { [@running, 60.0 / (@bpm * PPQN)] }
        break unless running

        next_tick += interval
        sleep_time = next_tick - monotonic_now
        sleep(sleep_time) if sleep_time.positive?

        callbacks, tick = @mutex.synchronize do
          next [nil, nil] unless @running

          @tick_count += 1
          [@callbacks.dup, @tick_count]
        end
        next unless callbacks

        callbacks.each { |cb| safely_call(cb, tick) }
      end
    end

    def safely_call(callback, tick)
      callback.call(tick)
    rescue => e
      error_callbacks = @mutex.synchronize { @error_callbacks.dup }
      error_callbacks.each { |cb| cb.call(e, tick) }
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def validate_bpm!(bpm)
      return if bpm.is_a?(Numeric) && bpm.positive?

      raise InvalidMessageError, "BPM must be positive, got #{bpm.inspect}"
    end
  end
end
