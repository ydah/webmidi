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

    it "raises on missing null terminators" do
      expect { described_class.decode_message("/bad".b) }
        .to raise_error(Webmidi::InvalidMessageError, /null terminator/)
    end

    it "raises on truncated arguments" do
      data = described_class.encode_string("/bad") + described_class.encode_string(",i") + "\x00".b
      expect { described_class.decode_message(data) }
        .to raise_error(Webmidi::InvalidMessageError, /ended/)
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

  it "does not register duplicate MIDI callbacks when started twice" do
    registrations = 0
    midi_input = Class.new do
      define_method(:on_message) do |&block|
        registrations += 1
        Webmidi::CallbackSubscription.new {}
      end
    end.new

    bridge = described_class.new(midi_input: midi_input)
    bridge.start
    bridge.start
    bridge.stop

    expect(registrations).to eq(1)
  end

  it "converts OSC messages to MIDI" do
    bridge = described_class.new
    data = Webmidi::Network::OSC::Encoder.encode_message("/midi/note/on", 2, 60, 100)

    message = bridge.receive_osc(data)

    expect(message).to be_a(Webmidi::Message::Channel::NoteOn)
    expect(message.channel).to eq(2)
  end
end
