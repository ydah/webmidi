# frozen_string_literal: true

module Webmidi
  module Port
    class Map
      include Enumerable

      def initialize(ports = [])
        @ports = {}
        ports.each { |port| @ports[port.id] = port }
      end

      def [](id_or_name)
        @ports[id_or_name] || @ports.values.find { |p| p.name == id_or_name }
      end

      def each(&block)
        @ports.values.each(&block)
      end

      def size
        @ports.size
      end

      def add(port)
        @ports[port.id] = port
        self
      end

      def remove(port_or_id)
        id = port_or_id.is_a?(String) ? port_or_id : port_or_id.id
        @ports.delete(id)
        self
      end

      def to_a
        @ports.values
      end

      def empty?
        @ports.empty?
      end
    end
  end
end
