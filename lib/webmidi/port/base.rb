# frozen_string_literal: true

require_relative "../callback_subscription"

module Webmidi
  module Port
    class Base
      attr_reader :id, :name, :manufacturer, :version, :type

      def initialize(id:, name:, manufacturer:, version:, type:, transport_handle:, sysex_enabled: false)
        @id = id
        @name = name
        @manufacturer = manufacturer
        @version = version
        @type = type
        @transport_handle = transport_handle
        @sysex_enabled = sysex_enabled
        @state = :connected
        @connection = :closed
        @state_change_callbacks = []
        @mutex = Mutex.new
      end

      def sysex_enabled?
        @mutex.synchronize { @sysex_enabled }
      end

      def state
        @mutex.synchronize { @state }
      end

      def connection
        @mutex.synchronize { @connection }
      end

      def open
        callbacks = @mutex.synchronize do
          return self if @connection == :open

          @connection = :open
          @state_change_callbacks.dup
        end
        callbacks.each { |cb| cb.call(self) }
        self
      end

      def close
        callbacks = @mutex.synchronize do
          was_open = @connection == :open
          @connection = :closed
          @transport_handle&.close
          was_open ? @state_change_callbacks.dup : []
        end
        callbacks.each { |cb| cb.call(self) }
        self
      end

      def open?
        connection == :open
      end

      def connected?
        state == :connected
      end

      def on_state_change(&block)
        raise ArgumentError, "on_state_change requires a block" unless block

        @mutex.synchronize { @state_change_callbacks << block }
        CallbackSubscription.new do
          @mutex.synchronize { @state_change_callbacks.delete(block) }
        end
      end

      def disconnect
        callbacks = @mutex.synchronize do
          return self if @state == :disconnected

          @state = :disconnected
          @connection = :closed
          @transport_handle&.close
          @state_change_callbacks.dup
        end
        callbacks.each { |cb| cb.call(self) }
        self
      end
    end
  end
end
