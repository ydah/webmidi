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
    in {status: :note_on, note: 60}
      matched = true
    end
    expect(matched).to be true
  end

  it "can copy with changed attributes" do
    copy = msg.with(note: 61, timestamp: 10.0)

    expect(copy).to be_a(described_class)
    expect(copy.note).to eq(61)
    expect(copy.velocity).to eq(0xC000)
    expect(copy.timestamp).to eq(10.0)
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

  it "can copy with changed attributes" do
    copy = msg.with(data1: 61)

    expect(copy).to be_a(described_class)
    expect(copy.data1).to eq(61)
    expect(copy.data2).to eq(100)
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

    it "converts PolyphonicPressure" do
      midi1 = Webmidi::Message.polyphonic_pressure(60, 80, channel: 3)
      midi2 = described_class.upgrade(midi1)

      expect(midi2.status).to eq(:poly_pressure)
      expect(midi2.note).to eq(60)
      expect(midi2.channel).to eq(3)
      expect(midi2.velocity).to eq(41_282)
    end

    it "converts ProgramChange" do
      midi1 = Webmidi::Message.program_change(10, channel: 4)
      midi2 = described_class.upgrade(midi1)

      expect(midi2.status).to eq(:program_change)
      expect(midi2.note).to eq(10)
      expect(midi2.channel).to eq(4)
    end

    it "converts ChannelPressure" do
      midi1 = Webmidi::Message.channel_pressure(80, channel: 6)
      midi2 = described_class.upgrade(midi1)

      expect(midi2.status).to eq(:channel_pressure)
      expect(midi2.channel).to eq(6)
      expect(midi2.velocity).to eq(2_705_491_209)
    end

    it "converts PitchBend" do
      midi1 = Webmidi::Message.pitch_bend(0, channel: 2)
      midi2 = described_class.upgrade(midi1, group: 1)

      expect(midi2.status).to eq(:pitch_bend)
      expect(midi2.channel).to eq(2)
      expect(midi2.group).to eq(1)
      expect(midi2.velocity).to eq(0)
      expect(midi2.to_bytes).to eq([0x41, 0xE2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    end

    it "preserves scaling endpoints" do
      expect(described_class.upgrade(Webmidi::Message.note_on(60, velocity: 0)).velocity).to eq(0)
      expect(described_class.upgrade(Webmidi::Message.note_on(60, velocity: 127)).velocity).to eq(0xFFFF)
      expect(described_class.upgrade(Webmidi::Message.pitch_bend(0)).velocity).to eq(0)
      expect(described_class.upgrade(Webmidi::Message.pitch_bend(16_383)).velocity).to eq(0xFFFF_FFFF)
    end

    it "exposes the MIDI 1.0 to UMP correspondence table" do
      expect(described_class::MIDI1_CHANNEL_VOICE_TO_UMP)
        .to include(Webmidi::Message::Channel::ProgramChange => include(status: :program_change))
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

    it "round-trips ProgramChange through upgrade/downgrade" do
      original = Webmidi::Message.program_change(32, channel: 7)
      downgraded = described_class.downgrade(described_class.upgrade(original))

      expect(downgraded).to be_a(Webmidi::Message::Channel::ProgramChange)
      expect(downgraded.program).to eq(32)
      expect(downgraded.channel).to eq(7)
    end

    it "round-trips ChannelPressure through upgrade/downgrade" do
      original = Webmidi::Message.channel_pressure(80, channel: 3)
      downgraded = described_class.downgrade(described_class.upgrade(original))

      expect(downgraded).to be_a(Webmidi::Message::Channel::ChannelPressure)
      expect(downgraded.pressure).to eq(80)
      expect(downgraded.channel).to eq(3)
    end

    it "round-trips PolyphonicPressure through upgrade/downgrade" do
      original = Webmidi::Message.polyphonic_pressure(60, 90, channel: 2)
      downgraded = described_class.downgrade(described_class.upgrade(original))

      expect(downgraded).to be_a(Webmidi::Message::Channel::PolyphonicPressure)
      expect(downgraded.note).to eq(60)
      expect(downgraded.pressure).to eq(90)
      expect(downgraded.channel).to eq(2)
    end

    it "round-trips PitchBend through upgrade/downgrade" do
      original = Webmidi::Message.pitch_bend(12_345, channel: 8)
      downgraded = described_class.downgrade(described_class.upgrade(original))

      expect(downgraded).to be_a(Webmidi::Message::Channel::PitchBend)
      expect(downgraded.value).to eq(12_345)
      expect(downgraded.channel).to eq(8)
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

    it "can copy raw message type subclasses" do
      msg = Webmidi::Message::UMP::Data64.new(words: [0x30000000, 0x00000000])
      copy = msg.with(timestamp: 12.0)

      expect(copy).to be_a(Webmidi::Message::UMP::Data64)
      expect(copy.words).to eq([0x30000000, 0x00000000])
      expect(copy.timestamp).to eq(12.0)
    end

    it "rejects raw words with a mismatched message type" do
      expect do
        Webmidi::Message::UMP::Data64.new(words: [0x20000000, 0x00000000])
      end.to raise_error(Webmidi::InvalidMessageError, /message type/)
    end

    it "rejects raw words with a mismatched group" do
      expect do
        Webmidi::Message::UMP::Data64.new(words: [0x31000000, 0x00000000], group: 2)
      end.to raise_error(Webmidi::InvalidMessageError, /group/)
    end
  end
end
