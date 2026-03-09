# frozen_string_literal: true

RSpec.describe Webmidi::Network::OSC::Encoder do
  describe ".encode_message / .decode_message" do
    it "round-trips an OSC message with int args" do
      encoded = described_class.encode_message("/midi/note/on", 0, 60, 100)
      address, args = described_class.decode_message(encoded)
      expect(address).to eq("/midi/note/on")
      expect(args).to eq([0, 60, 100])
    end

    it "round-trips an OSC message with string args" do
      encoded = described_class.encode_message("/test", "hello")
      address, args = described_class.decode_message(encoded)
      expect(address).to eq("/test")
      expect(args).to eq(["hello"])
    end

    it "round-trips float args" do
      encoded = described_class.encode_message("/volume", 0.75)
      address, args = described_class.decode_message(encoded)
      expect(address).to eq("/volume")
      expect(args.first).to be_within(0.001).of(0.75)
    end
  end
end

RSpec.describe Webmidi::Network::OSC::Bridge do
  it "has default mappings" do
    bridge = described_class.new
    expect(bridge.mapping).to include(Webmidi::Message::Channel::NoteOn => "/midi/note/on")
  end

  it "supports custom mapping" do
    bridge = described_class.new
    bridge.custom_mapping do |m|
      m[Webmidi::Message::Channel::NoteOn] = "/custom/note"
    end
    expect(bridge.mapping[Webmidi::Message::Channel::NoteOn]).to eq("/custom/note")
  end
end
