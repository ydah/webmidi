# frozen_string_literal: true

require_relative "middleware/base"
require_relative "middleware/stack"
require_relative "middleware/logger"
require_relative "middleware/filter"
require_relative "middleware/transpose"
require_relative "middleware/velocity_scale"
require_relative "middleware/channel_map"
require_relative "middleware/note_range_filter"
require_relative "middleware/velocity_clamp"
require_relative "middleware/timing_gate"
require_relative "middleware/recorder"
require_relative "middleware/pipeline"

module Webmidi
  module Middleware
  end
end
