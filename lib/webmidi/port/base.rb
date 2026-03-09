# frozen_string_literal: true

module Webmidi
  module Port
    class Base
      attr_reader :id, :name, :manufacturer, :version, :type

      def initialize(id:, name:, manufacturer:, version:, type:, transport_handle:)
        @id = id
        @name = name
        @manufacturer = manufacturer
        @version = version
        @type = type
        @transport_handle = transport_handle
        @state = :closed
        @connection = :closed
        @state_change_callbacks = []
        @mutex = Mutex.new
      end

      def state
        @mutex.synchronize { @state }
      end

      def connection
        @mutex.synchronize { @connection }
      end

      def open
        callbacks = @mutex.synchronize do
          return self if @state == :open

          @state = :open
          @connection = :open
          @state_change_callbacks.dup
        end
        callbacks.each { |cb| cb.call(self) }
        self
      end

      def close
        callbacks = @mutex.synchronize do
          return self if @state == :closed

          @state = :closed
          @connection = :closed
          @transport_handle&.close
          @state_change_callbacks.dup
        end
        callbacks.each { |cb| cb.call(self) }
        self
      end

      def open?
        state == :open
      end

      def connected?
        connection == :open
      end

      def on_state_change(&block)
        @mutex.synchronize { @state_change_callbacks << block }
        self
      end

      private

      def notify_state_change
        @state_change_callbacks.each { |cb| cb.call(self) }
      end
    end
  end
end
