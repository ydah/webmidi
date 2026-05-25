# frozen_string_literal: true

RSpec.describe Webmidi::Message::System::SysEx do
  subject(:msg) { described_class.new(data: [0x7E, 0x7F, 0x09, 0x01]) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7])
  end

  it "freezes data" do
    expect(msg.data).to be_frozen
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end

  it "validates data bytes" do
    expect { described_class.new(data: [0x80]) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  it "supports pattern matching" do
    case msg
    in {data: [0x7E, *]}
      matched = true
    end
    expect(matched).to be true
  end

  it "splits and joins long data" do
    chunks = msg.chunks(max_data_bytes: 2)
    expect(chunks.map(&:data)).to eq([[0x7E, 0x7F], [0x09, 0x01]])
    expect(described_class.join(chunks).data).to eq(msg.data)
  end
end

RSpec.describe Webmidi::Message::System::TimeCode do
  subject(:msg) { described_class.new(type: 3, value: 10) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xF1, 0x3A])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end

  it "validates type range" do
    expect { described_class.new(type: 8, value: 0) }
      .to raise_error(Webmidi::InvalidMessageError)
  end
end

RSpec.describe Webmidi::Message::System::SongPosition do
  subject(:msg) { described_class.new(position: 8192) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xF2, 0x00, 0x40])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::System::SongSelect do
  subject(:msg) { described_class.new(song: 5) }

  it "has correct bytes" do
    expect(msg.to_bytes).to eq([0xF3, 5])
  end

  it "round-trips through bytes" do
    parsed = Webmidi::Message.from_bytes(*msg.to_bytes)
    expect(parsed).to eq(msg)
  end
end

RSpec.describe Webmidi::Message::System::TuneRequest do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xF6])
  end
end

RSpec.describe Webmidi::Message::System::Clock do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xF8])
  end
end

RSpec.describe Webmidi::Message::System::Start do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xFA])
  end
end

RSpec.describe Webmidi::Message::System::Continue do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xFB])
  end
end

RSpec.describe Webmidi::Message::System::Stop do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xFC])
  end
end

RSpec.describe Webmidi::Message::System::ActiveSensing do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xFE])
  end
end

RSpec.describe Webmidi::Message::System::SystemReset do
  it "has correct bytes" do
    expect(described_class.new.to_bytes).to eq([0xFF])
  end
end
