# frozen_string_literal: true

RSpec.describe Webmidi::Transport do
  after { Webmidi.reset_configuration! }

  def adapter_class(available: true)
    Class.new do
      define_singleton_method(:available?) { available }
      define_singleton_method(:list_inputs) { [] }
      define_singleton_method(:list_outputs) { [] }
      define_singleton_method(:open_input) { |_device_info| nil }
      define_singleton_method(:open_output) { |_device_info| nil }
    end
  end

  describe ".auto_detect" do
    it "honors explicit virtual transport configuration" do
      Webmidi.configure { |config| config.transport = :virtual }
      expect(described_class.auto_detect).to eq(Webmidi::Transport::Virtual)
    end

    it "honors explicit null transport configuration" do
      Webmidi.configure { |config| config.transport = :null }
      expect(described_class.auto_detect).to eq(Webmidi::Transport::Null)
    end

    it "rejects unknown transport symbols" do
      Webmidi.configure { |config| config.transport = :alsa }
      expect { described_class.auto_detect }.to raise_error(Webmidi::TransportNotAvailableError)
    end

    it "detects registered adapter transports before virtual fallback" do
      adapter = adapter_class

      described_class.register(adapter)
      expect(described_class.auto_detect).to eq(adapter)
    ensure
      described_class.unregister(adapter) if adapter
    end

    it "uses configured fallback when no auto-detect candidates are available" do
      unavailable = adapter_class(available: false)

      expect(described_class.auto_detect(candidates: [unavailable], fallback_transport: :null))
        .to eq(Webmidi::Transport::Null)
    end
  end

  describe ".register / .unregister" do
    it "keeps a defensive snapshot of registered adapter transports" do
      adapter = adapter_class

      2.times { described_class.register(adapter) }
      registered = described_class.registered

      expect(registered.count { |transport| transport == adapter }).to eq(1)
      expect { registered << adapter }.to raise_error(FrozenError)
    ensure
      described_class.unregister(adapter) if adapter
    end

    it "rejects invalid adapter objects" do
      expect { described_class.register(Object.new) }
        .to raise_error(Webmidi::TransportNotAvailableError, /missing/)
    end
  end

  describe ".load_adapter" do
    it "loads and registers an adapter constant using adapter gem naming conventions" do
      adapter = adapter_class
      stub_const("Webmidi::Transport::CoreMidi", adapter)

      loaded = described_class.load_adapter(:core_midi, require_path: nil)

      expect(loaded).to eq(adapter)
      expect(Webmidi::Transport::Adapter.gem_name(:core_midi)).to eq("webmidi-core-midi")
      expect(Webmidi::Transport::Adapter.require_path(:core_midi)).to eq("webmidi/transport/core_midi")
    ensure
      described_class.unregister(adapter) if adapter
    end
  end
end
