# frozen_string_literal: true

RSpec.describe Webmidi::Message::Channel::NoteOn do
  subject(:msg) { described_class.new(note: 60, velocity: 100, channel: 0) }

  it "is frozen" do
    expect(msg).to be_frozen
  end

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0x90, 60, 100])
  end

  it "has correct hex" do
    expect(msg.to_hex).to eq("90 3C 64")
  end

  it "has a timestamp" do
    expect(msg.timestamp).to be_a(Float)
  end

  it "supports equality" do
    other = described_class.new(note: 60, velocity: 100, channel: 0)
    expect(msg).to eq(other)
  end

  it "can copy with changed attributes while preserving timestamp" do
    changed = msg.with(note: 62)
    expect(changed.note).to eq(62)
    expect(changed.velocity).to eq(100)
    expect(changed.timestamp).to eq(msg.timestamp)
  end

  it "supports binary output and event comparison" do
    other = described_class.new(note: 60, velocity: 100, channel: 0, timestamp: msg.timestamp)
    expect(msg.to_binary).to eq([0x90, 60, 100].pack("C*").b)
    expect(msg.same_bytes?(other)).to be true
    expect(msg.same_event?(other)).to be true
  end

  it "supports pattern matching" do
    case msg
    in {note: 60, velocity: (80..)}
      matched = true
    end
    expect(matched).to be true
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end

  it "validates channel range" do
    expect { described_class.new(note: 60, velocity: 100, channel: 16) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  it "validates note range" do
    expect { described_class.new(note: 128, velocity: 100, channel: 0) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  it "validates velocity range" do
    expect { described_class.new(note: 60, velocity: 128, channel: 0) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  context "with channel 5" do
    subject(:msg) { described_class.new(note: 72, velocity: 80, channel: 5) }

    it "encodes channel in status byte" do
      expect(msg.to_bytes).to eq([0x95, 72, 80])
    end
  end
end

RSpec.describe Webmidi::Message::Channel::NoteOff do
  subject(:msg) { described_class.new(note: 60, velocity: 64, channel: 0) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0x80, 60, 64])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::Channel::PolyphonicPressure do
  subject(:msg) { described_class.new(note: 60, pressure: 100, channel: 0) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xA0, 60, 100])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::Channel::ControlChange do
  subject(:msg) { described_class.new(cc: 7, value: 100, channel: 0) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xB0, 7, 100])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end

  it "accepts named controllers" do
    named = described_class.new(cc: :all_notes_off, value: 0)
    expect(named.cc).to eq(described_class::ALL_NOTES_OFF)
  end
end

RSpec.describe Webmidi::Message::Channel::ProgramChange do
  subject(:msg) { described_class.new(program: 42, channel: 3) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xC3, 42])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::Channel::ChannelPressure do
  subject(:msg) { described_class.new(pressure: 80, channel: 0) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xD0, 80])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::Channel::PitchBend do
  subject(:msg) { described_class.new(value: 8192, channel: 0) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xE0, 0x00, 0x40])
  end

  it "encodes center value correctly" do
    expect(msg.to_bytes[1]).to eq(0x00)
    expect(msg.to_bytes[2]).to eq(0x40)
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end

  it "validates range" do
    expect { described_class.new(value: 16384, channel: 0) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  it "supports signed values" do
    msg = described_class.from_signed(-8192)
    expect(msg.value).to eq(0)
    expect(msg.signed_value).to eq(-8192)
  end

  context "with minimum value" do
    subject(:msg) { described_class.new(value: 0, channel: 0) }

    it "has correct bytes" do
      expect(msg.to_bytes).to eq([0xE0, 0x00, 0x00])
    end
  end

  context "with maximum value" do
    subject(:msg) { described_class.new(value: 16383, channel: 0) }

    it "has correct bytes" do
      expect(msg.to_bytes).to eq([0xE0, 0x7F, 0x7F])
    end
  end
end
