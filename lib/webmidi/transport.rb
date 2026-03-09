# frozen_string_literal: true

require_relative "transport/device_info"
require_relative "transport/base"
require_relative "transport/virtual"
require_relative "transport/null"

module Webmidi
  module Transport
    module_function

    def auto_detect
      if Virtual.available?
        Virtual
      else
        Null
      end
    end
  end
end
