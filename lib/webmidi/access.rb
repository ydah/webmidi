# frozen_string_literal: true

module Webmidi
  class Access
    include Enumerable

    attr_reader :sysex_enabled

    alias sysex_enabled? sysex_enabled

    def initialize(sysex: false, transport: nil)
      @sysex_enabled = sysex
      @transport = transport || Transport.auto_detect
      @inputs = Port::Map.new
      @outputs = Port::Map.new
      @state_change_callbacks = []
      @mutex = Mutex.new
      refresh_ports
    end

    def inputs
      @mutex.synchronize { @inputs }
    end

    def outputs
      @mutex.synchronize { @outputs }
    end

    def input(name_or_id)
      inputs[name_or_id]
    end

    def output(name_or_id)
      outputs[name_or_id]
    end

    def on_state_change(&block)
      @mutex.synchronize { @state_change_callbacks << block }
      self
    end

    def close
      inputs.each(&:close)
      outputs.each(&:close)
      self
    end

    def each(&block)
      (inputs.to_a + outputs.to_a).each(&block)
    end

    def create_input(name)
      handle = @transport.create_virtual_input(name)
      port = Port::Input.new(
        id: handle.device_info.id,
        name: handle.device_info.name,
        manufacturer: handle.device_info.manufacturer,
        version: handle.device_info.version,
        transport_handle: handle
      )
      @mutex.synchronize { @inputs.add(port) }
      port
    end

    def create_output(name)
      handle = @transport.create_virtual_output(name)
      port = Port::Output.new(
        id: handle.device_info.id,
        name: handle.device_info.name,
        manufacturer: handle.device_info.manufacturer,
        version: handle.device_info.version,
        transport_handle: handle
      )
      @mutex.synchronize { @outputs.add(port) }
      port
    end

    private

    def refresh_ports
      @transport.list_inputs.each do |info|
        handle = @transport.respond_to?(:open_input) ? @transport.open_input(info) : nil
        port = Port::Input.new(
          id: info.id, name: info.name,
          manufacturer: info.manufacturer, version: info.version,
          transport_handle: handle
        )
        @inputs.add(port)
      end

      @transport.list_outputs.each do |info|
        handle = @transport.respond_to?(:open_output) ? @transport.open_output(info) : nil
        port = Port::Output.new(
          id: info.id, name: info.name,
          manufacturer: info.manufacturer, version: info.version,
          transport_handle: handle
        )
        @outputs.add(port)
      end
    end
  end

  class << self
    def request_access(sysex: false, &block)
      access = Access.new(sysex: sysex)
      if block
        begin
          block.call(access)
        ensure
          access.close
        end
      else
        access
      end
    end
  end
end
