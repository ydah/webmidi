# frozen_string_literal: true

require "securerandom"
require "thread"

module Webmidi
  module Transport
    class Virtual < Base
      @ports = {}
      @mutex = Mutex.new

      def self.available?
        true
      end

      def self.list_inputs
        @mutex.synchronize { @ports.values.select { |p| p.is_a?(VirtualInputHandle) && !p.closed? }.map(&:device_info) }
      end

      def self.list_outputs
        @mutex.synchronize { @ports.values.select { |p| p.is_a?(VirtualOutputHandle) && !p.closed? }.map(&:device_info) }
      end

      def self.create_virtual_input(name)
        info = DeviceInfo.new(id: generate_id, name: name, manufacturer: "Webmidi Virtual", version: "1.0")
        handle = VirtualInputHandle.new(info, on_close: -> { unregister(info.id) })
        @mutex.synchronize { @ports[info.id] = handle }
        handle
      end

      def self.create_virtual_output(name)
        info = DeviceInfo.new(id: generate_id, name: name, manufacturer: "Webmidi Virtual", version: "1.0")
        handle = VirtualOutputHandle.new(info, on_close: -> { unregister(info.id) })
        @mutex.synchronize { @ports[info.id] = handle }
        handle
      end

      def self.create_loopback(name)
        input = create_virtual_input(name)
        output = create_virtual_output(name)
        output.connect(input)
        [input, output]
      end

      def self.reset!
        handles = @mutex.synchronize { @ports.values.dup }
        handles.each(&:close)
        @mutex.synchronize { @ports.clear }
      end

      def self.generate_id
        "virtual-#{SecureRandom.uuid}"
      end

      def self.unregister(id)
        @mutex.synchronize { @ports.delete(id) }
      end
      private_class_method :generate_id

      class VirtualInputHandle
        include InputHandle

        attr_reader :device_info

        def initialize(device_info, on_close: nil)
          @device_info = device_info
          @on_close = on_close
          @queue = Thread::Queue.new
          @callbacks = []
          @mutex = Mutex.new
          @closed = false
        end

        def read(timeout: nil)
          return nil if @closed

          if timeout
            @queue.pop(timeout: timeout)
          else
            @queue.pop(true) rescue nil
          end
        end

        def on_data(&block)
          @mutex.synchronize { @callbacks << block }
        end

        def receive(bytes)
          return if @closed

          @queue.push(bytes)
          @mutex.synchronize { @callbacks.dup }.each { |cb| cb.call(bytes) }
        end

        def close
          return if @closed

          @closed = true
          @queue.close
          @on_close&.call
        end

        def closed?
          @closed
        end
      end

      class VirtualOutputHandle
        include OutputHandle

        attr_reader :device_info

        def initialize(device_info, on_close: nil)
          @device_info = device_info
          @on_close = on_close
          @connected_inputs = []
          @mutex = Mutex.new
          @closed = false
          @sent_messages = []
        end

        def write(bytes)
          raise PortClosedError, "Port is closed" if @closed

          connected_inputs = @mutex.synchronize do
            @sent_messages << bytes
            @connected_inputs.dup
          end
          connected_inputs.each { |input| input.receive(bytes) }
        end

        def connect(input_handle)
          @mutex.synchronize do
            @connected_inputs << input_handle unless @connected_inputs.include?(input_handle)
          end
        end

        def disconnect(input_handle)
          @mutex.synchronize { @connected_inputs.delete(input_handle) }
        end

        def sent_messages
          @mutex.synchronize { @sent_messages.dup }
        end

        def close
          return if @closed

          @closed = true
          @on_close&.call
        end

        def closed?
          @closed
        end
      end
    end
  end
end
