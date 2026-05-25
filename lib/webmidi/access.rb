# frozen_string_literal: true

require_relative "callback_subscription"

module Webmidi
  class Access
    include Enumerable

    attr_reader :sysex_enabled

    alias sysex_enabled? sysex_enabled

    def initialize(sysex: false, transport: nil)
      @sysex_enabled = sysex
      @transport = transport ? Transport.send(:resolve_transport!, transport) : Transport.auto_detect
      @inputs = Port::Map.new
      @outputs = Port::Map.new
      @state_change_callbacks = []
      @port_state_subscriptions = []
      @mutex = Mutex.new
      refresh_ports
    end

    def inputs
      @mutex.synchronize { @inputs.snapshot }
    end

    def outputs
      @mutex.synchronize { @outputs.snapshot }
    end

    def input(name_or_id)
      @mutex.synchronize { @inputs[name_or_id] }
    end

    def output(name_or_id)
      @mutex.synchronize { @outputs[name_or_id] }
    end

    def fetch_input!(name_or_id)
      input(name_or_id) || raise(PortNotFoundError, "Input port not found: #{name_or_id}")
    end

    def fetch_output!(name_or_id)
      output(name_or_id) || raise(PortNotFoundError, "Output port not found: #{name_or_id}")
    end

    def on_state_change(&block)
      raise ArgumentError, "on_state_change requires a block" unless block

      @mutex.synchronize { @state_change_callbacks << block }
      CallbackSubscription.new do
        @mutex.synchronize { @state_change_callbacks.delete(block) }
      end
    end

    def close
      each(&:close)
      self
    end

    def each(&block)
      ports = @mutex.synchronize { @inputs.to_a + @outputs.to_a }
      ports.each(&block)
    end

    def create_input(name)
      handle = @transport.create_virtual_input(name)
      port = Port::Input.new(
        id: handle.device_info.id,
        name: handle.device_info.name,
        manufacturer: handle.device_info.manufacturer,
        version: handle.device_info.version,
        transport_handle: handle,
        sysex_enabled: @sysex_enabled
      )
      register_port(port, @inputs)
      port
    end

    def create_output(name)
      handle = @transport.create_virtual_output(name)
      port = Port::Output.new(
        id: handle.device_info.id,
        name: handle.device_info.name,
        manufacturer: handle.device_info.manufacturer,
        version: handle.device_info.version,
        transport_handle: handle,
        sysex_enabled: @sysex_enabled
      )
      register_port(port, @outputs)
      port
    end

    def refresh_ports
      sync_ports(@inputs, @transport.list_inputs, Port::Input, :open_input)
      sync_ports(@outputs, @transport.list_outputs, Port::Output, :open_output)
      self
    end

    private

    def sync_ports(map, infos, port_class, open_method)
      current_ids = infos.map(&:id)
      removed = []
      added = []

      @mutex.synchronize do
        map.to_a.reject { |port| current_ids.include?(port.id) }.each do |port|
          map.remove(port)
          removed << port
        end

        infos.each do |info|
          next if map[info.id]

          handle = @transport.respond_to?(open_method) ? @transport.public_send(open_method, info) : nil
          port = port_class.new(
            id: info.id, name: info.name,
            manufacturer: info.manufacturer, version: info.version,
            transport_handle: handle,
            sysex_enabled: @sysex_enabled
          )
          map.add(port)
          watch_port(port)
          added << port
        end
      end

      removed.each do |port|
        port.disconnect
        notify_state_change(port)
      end
      added.each { |port| notify_state_change(port) }
    end

    def register_port(port, map)
      @mutex.synchronize do
        map.add(port)
        watch_port(port)
      end
      notify_state_change(port)
    end

    def watch_port(port)
      subscription = port.on_state_change { |changed_port| notify_state_change(changed_port) }
      @port_state_subscriptions << subscription
    end

    def notify_state_change(port)
      callbacks = @mutex.synchronize { @state_change_callbacks.dup }
      callbacks.each { |cb| cb.call(port) }
    end
  end

  class << self
    def request_access(sysex: Webmidi.configuration.sysex, &block)
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
