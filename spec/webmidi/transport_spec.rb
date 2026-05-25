# frozen_string_literal: true

RSpec.describe Webmidi::Transport do
  after { Webmidi.reset_configuration! }

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
      adapter = Class.new do
        def self.available?
          true
        end
      end

      described_class.register(adapter)
      expect(described_class.auto_detect).to eq(adapter)
    ensure
      described_class.unregister(adapter) if adapter
    end

    it "uses configured fallback when no auto-detect candidates are available" do
      unavailable = Class.new do
        def self.available?
          false
        end
      end

      expect(described_class.auto_detect(candidates: [unavailable], fallback_transport: :null))
        .to eq(Webmidi::Transport::Null)
    end
  end

  describe ".register / .unregister" do
    it "keeps a defensive snapshot of registered adapter transports" do
      adapter = Class.new do
        def self.available?
          true
        end
      end

      2.times { described_class.register(adapter) }
      registered = described_class.registered

      expect(registered.count { |transport| transport == adapter }).to eq(1)
      expect { registered << adapter }.to raise_error(FrozenError)
    ensure
      described_class.unregister(adapter) if adapter
    end

    it "rejects invalid adapter objects" do
      expect { described_class.register(Object.new) }
        .to raise_error(Webmidi::TransportNotAvailableError, /available/)
    end
  end
end
