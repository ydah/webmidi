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
  end
end
