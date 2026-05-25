# frozen_string_literal: true

module Webmidi
  class CallbackSubscription
    def initialize(&unsubscribe)
      @unsubscribe = unsubscribe
      @active = true
      @mutex = Mutex.new
    end

    def unsubscribe
      callback = @mutex.synchronize do
        return false unless @active

        @active = false
        @unsubscribe
      end
      callback.call
      true
    end

    def active?
      @mutex.synchronize { @active }
    end
  end
end
