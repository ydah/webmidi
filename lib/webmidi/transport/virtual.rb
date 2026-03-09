# frozen_string_literal: true

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
        @mutex.synchronize { @ports.values.select { |p| p.is_a?(VirtualInputHandle) }.map(&:device_info) }
      end

      def self.list_outputs
        @mutex.synchronize { @ports.values.select { |p| p.is_a?(VirtualOutputHandle) }.map(&:device_info) }
      end

      def self.create_virtual_input(name)
        info = DeviceInfo.new(id: generate_id, name: name, manufacturer: "Webmidi Virtual", version: "1.0")
        handle = VirtualInputHandle.new(info)
        @mutex.synchronize { @ports[info.id] = handle }
        handle
      end

      def self.create_virtual_output(name)
        info = DeviceInfo.new(id: generate_id, name: name, manufacturer: "Webmidi Virtual", version: "1.0")
        handle = VirtualOutputHandle.new(info)
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
        @mutex.synchronize do
          @ports.each_value(&:close)
          @ports.clear
        end
      end

      def self.generate_id
        "virtual-#{SecureRandom.uuid}"
      end
      private_class_method :generate_id

      class VirtualInputHandle
        include InputHandle

        attr_reader :device_info

        def initialize(device_info)
          @device_info = device_info
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
          @closed = true
          @queue.close
        end

        def closed?
          @closed
        end
      end

      class VirtualOutputHandle
        include OutputHandle

        attr_reader :device_info

        def initialize(device_info)
          @device_info = device_info
          @connected_inputs = []
          @mutex = Mutex.new
          @closed = false
          @sent_messages = []
        end

        def write(bytes)
          raise PortClosedError, "Port is closed" if @closed

          @mutex.synchronize do
            @sent_messages << bytes
            @connected_inputs.each { |input| input.receive(bytes) }
          end
        end

        def connect(input_handle)
          @mutex.synchronize { @connected_inputs << input_handle }
        end

        def disconnect(input_handle)
          @mutex.synchronize { @connected_inputs.delete(input_handle) }
        end

        def sent_messages
          @mutex.synchronize { @sent_messages.dup }
        end

        def close
          @closed = true
        end

        def closed?
          @closed
        end
      end
    end
  end
end
