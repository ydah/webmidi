# frozen_string_literal: true

module Webmidi
  module Port
    class Map
      include Enumerable

      def initialize(ports = [], mutable: true)
        @ports = {}
        @mutable = mutable
        @mutex = Mutex.new
        ports.each { |port| @ports[port.id] = port }
      end

      def [](id_or_name)
        @mutex.synchronize do
          @ports[id_or_name] || @ports.values.find { |p| p.name == id_or_name }
        end
      end

      def each(&block)
        to_a.each(&block)
      end

      def size
        @mutex.synchronize { @ports.size }
      end

      def add(port)
        ensure_mutable!
        @mutex.synchronize { @ports[port.id] = port }
        self
      end

      def remove(port_or_id)
        ensure_mutable!
        id = port_or_id.is_a?(String) ? port_or_id : port_or_id.id
        @mutex.synchronize { @ports.delete(id) }
        self
      end

      def to_a
        @mutex.synchronize { @ports.values.dup }
      end

      def to_h
        @mutex.synchronize { @ports.dup }
      end

      def snapshot
        self.class.new(to_a, mutable: false)
      end

      def empty?
        @mutex.synchronize { @ports.empty? }
      end

      private

      def ensure_mutable!
        raise FrozenError, "Port::Map snapshot is read-only" unless @mutable
      end
    end
  end
end
