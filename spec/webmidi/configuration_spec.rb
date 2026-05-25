# frozen_string_literal: true

RSpec.describe Webmidi::Configuration do
  subject(:config) { described_class.new }

  describe "default values" do
    it "has auto transport" do
      expect(config.transport).to eq(:auto)
    end

    it "has virtual fallback transport" do
      expect(config.fallback_transport).to eq(:virtual)
    end

    it "has default channel 0" do
      expect(config.default_channel).to eq(0)
    end

    it "has default velocity 100" do
      expect(config.default_velocity).to eq(100)
    end

    it "has default group 0" do
      expect(config.default_group).to eq(0)
    end

    it "has sysex disabled" do
      expect(config.sysex).to be false
    end

    it "has monotonic timestamp source" do
      expect(config.timestamp_source).to eq(:monotonic)
    end
  end

  describe "#reset!" do
    it "resets to defaults" do
      config.transport = :alsa
      config.default_channel = 5
      config.reset!
      expect(config.transport).to eq(:auto)
      expect(config.default_channel).to eq(0)
    end
  end
end

RSpec.describe Webmidi do
  after { described_class.reset_configuration! }

  describe ".configure" do
    it "yields configuration" do
      described_class.configure do |config|
        config.transport = :virtual
        config.default_channel = 3
      end

      expect(described_class.configuration.transport).to eq(:virtual)
      expect(described_class.configuration.default_channel).to eq(3)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Webmidi::Configuration)
    end

    it "returns the same instance" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration" do
      old = described_class.configuration
      described_class.reset_configuration!
      expect(described_class.configuration).not_to equal(old)
    end
  end
end
