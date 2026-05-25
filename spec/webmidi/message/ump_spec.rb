# frozen_string_literal: true

RSpec.describe Webmidi::Message::UMP::ChannelVoice64 do
  subject(:msg) do
    described_class.new(
      status: :note_on,
      group: 0,
      channel: 0,
      note: 60,
      velocity: 0xC000
    )
  end

  it "is frozen" do
    expect(msg).to be_frozen
  end

  it "has 8 bytes" do
    expect(msg.to_bytes.size).to eq(8)
  end

  it "uses the MIDI 2.0 channel voice bit layout" do
    expect(msg.to_bytes).to eq([0x40, 0x90, 0x3C, 0x00, 0xC0, 0x00, 0x00, 0x00])
  end

  it "supports pattern matching" do
    case msg
    in { status: :note_on, note: 60 }
      matched = true
    end
    expect(matched).to be true
  end
end

RSpec.describe Webmidi::Message::UMP::ChannelVoice32 do
  subject(:msg) do
    described_class.new(
      status: :note_on,
      group: 0,
      channel: 0,
      data1: 60,
      data2: 100
    )
  end

  it "has 4 bytes" do
    expect(msg.to_bytes.size).to eq(4)
  end

  it "uses the MIDI 1.0 UMP channel voice bit layout" do
    expect(msg.to_bytes).to eq([0x20, 0x90, 60, 100])
  end
end

RSpec.describe Webmidi::Message::UMP do
  describe ".upgrade" do
    it "converts NoteOn from MIDI 1.0 to 2.0" do
      midi1 = Webmidi::Message.note_on(60, velocity: 100, channel: 0)
      midi2 = described_class.upgrade(midi1)

      expect(midi2).to be_a(Webmidi::Message::UMP::ChannelVoice64)
      expect(midi2.status).to eq(:note_on)
      expect(midi2.note).to eq(60)
      expect(midi2.channel).to eq(0)
      expect(midi2.velocity).to eq(51_602)
    end

    it "converts NoteOff" do
      midi1 = Webmidi::Message.note_off(60, velocity: 64)
      midi2 = described_class.upgrade(midi1)

      expect(midi2.status).to eq(:note_off)
      expect(midi2.note).to eq(60)
    end

    it "converts ControlChange" do
      midi1 = Webmidi::Message.control_change(1, 64, channel: 2)
      midi2 = described_class.upgrade(midi1)

      expect(midi2.status).to eq(:control_change)
      expect(midi2.note).to eq(1)
      expect(midi2.channel).to eq(2)
      expect(midi2.velocity).to eq(2_164_392_968)
    end

    it "preserves scaling endpoints" do
      expect(described_class.upgrade(Webmidi::Message.note_on(60, velocity: 0)).velocity).to eq(0)
      expect(described_class.upgrade(Webmidi::Message.note_on(60, velocity: 127)).velocity).to eq(0xFFFF)
    end
  end

  describe ".downgrade" do
    it "converts NoteOn from MIDI 2.0 to 1.0" do
      midi2 = Webmidi::Message::UMP::ChannelVoice64.new(
        status: :note_on,
        channel: 0,
        note: 60,
        velocity: 51_602
      )
      midi1 = described_class.downgrade(midi2)

      expect(midi1).to be_a(Webmidi::Message::Channel::NoteOn)
      expect(midi1.note).to eq(60)
      expect(midi1.velocity).to eq(100)
    end

    it "round-trips through upgrade/downgrade" do
      original = Webmidi::Message.note_on(72, velocity: 80, channel: 5)
      upgraded = described_class.upgrade(original)
      downgraded = described_class.downgrade(upgraded)

      expect(downgraded.note).to eq(72)
      expect(downgraded.velocity).to eq(80)
      expect(downgraded.channel).to eq(5)
    end
  end

  describe ".from_bytes / .from_words" do
    it "parses a MIDI 2.0 channel voice message" do
      msg = described_class.from_bytes([0x40, 0x90, 0x3C, 0x00, 0xC0, 0x00, 0x00, 0x00])
      expect(msg).to be_a(Webmidi::Message::UMP::ChannelVoice64)
      expect(msg.status).to eq(:note_on)
      expect(msg.note).to eq(60)
      expect(msg.velocity).to eq(0xC000)
    end

    it "parses generic message type classes" do
      msg = described_class.from_words(0x30000000, 0x00000000)
      expect(msg).to be_a(Webmidi::Message::UMP::Data64)
    end
  end
end
