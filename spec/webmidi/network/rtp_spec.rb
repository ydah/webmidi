# frozen_string_literal: true

RSpec.describe Webmidi::Network::RTP::Packet do
  describe "round-trip" do
    it "serializes and deserializes a packet" do
      original = described_class.new(
        sequence_number: 42,
        timestamp: 1000,
        ssrc: 12345,
        midi_data: [0x90, 60, 100]
      )

      bytes = original.to_bytes
      parsed = described_class.parse(bytes)

      expect(parsed.sequence_number).to eq(42)
      expect(parsed.timestamp).to eq(1000)
      expect(parsed.ssrc).to eq(12345)
      expect(parsed.midi_data).to eq([0x90, 60, 100])
    end
  end

  describe ".parse" do
    it "returns nil for too-short data" do
      expect(described_class.parse("short")).to be_nil
    end
  end
end

RSpec.describe Webmidi::Network::RTP::Session do
  it "can be created as server" do
    session = Webmidi::Network::RTP.server(port: 0, name: "Test")
    expect(session.name).to eq("Test")
    session.start
    expect(session.port).to be > 0
    session.close
  end
end
