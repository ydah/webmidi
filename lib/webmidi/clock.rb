# frozen_string_literal: true

module Webmidi
  class Clock
    PPQN = 24

    attr_reader :bpm, :running

    alias running? running

    def initialize(bpm: 120)
      @bpm = bpm
      @running = false
      @callbacks = []
      @mutex = Mutex.new
      @thread = nil
      @tick_count = 0
    end

    def bpm=(new_bpm)
      @mutex.synchronize { @bpm = new_bpm }
    end

    def start
      @running = true
      @tick_count = 0
      @thread = Thread.new { clock_loop }
      self
    end

    def stop
      @running = false
      @thread&.join(1)
      @thread = nil
      self
    end

    def on_tick(&block)
      @mutex.synchronize { @callbacks << block }
      self
    end

    def tick_count
      @mutex.synchronize { @tick_count }
    end

    def beat_count
      @mutex.synchronize { @tick_count / PPQN }
    end

    private

    def clock_loop
      while @running
        interval = 60.0 / (@bpm * PPQN)
        sleep(interval)

        @mutex.synchronize do
          @tick_count += 1
          @callbacks.each { |cb| cb.call(@tick_count) }
        end
      end
    end
  end
end
