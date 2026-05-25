# frozen_string_literal: true

module Webmidi
  class Configuration
    attr_accessor :transport, :fallback_transport,
                  :default_channel, :default_velocity,
                  :default_group,
                  :sysex,
                  :logger, :log_level,
                  :timestamp_source

    def initialize
      reset!
    end

    def reset!
      @transport = :auto
      @fallback_transport = :virtual
      @default_channel = 0
      @default_velocity = 100
      @default_group = 0
      @sysex = false
      @logger = nil
      @log_level = :info
      @timestamp_source = :monotonic
      self
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
