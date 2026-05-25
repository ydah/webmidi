# frozen_string_literal: true

module Webmidi
  module Transport
    module Adapter
      REQUIRED_METHODS = %i[
        available?
        list_inputs
        list_outputs
        open_input
        open_output
      ].freeze

      module_function

      def validate!(transport)
        missing = REQUIRED_METHODS.reject { |method| transport.respond_to?(method) }
        return transport if missing.empty?

        raise TransportNotAvailableError,
          "Transport adapter #{transport.inspect} is missing: #{missing.join(", ")}"
      end

      def gem_name(name)
        "webmidi-#{normalized_name(name).tr("_", "-")}"
      end

      def require_path(name)
        "webmidi/transport/#{normalized_name(name)}"
      end

      def constant_name(name)
        camel = normalized_name(name).split("_").map(&:capitalize).join
        "Webmidi::Transport::#{camel}"
      end

      def constantize(path)
        path.split("::").reduce(Object) { |namespace, const_name| namespace.const_get(const_name) }
      end

      def normalized_name(name)
        name.to_s.tr("-", "_")
      end
    end
  end
end
