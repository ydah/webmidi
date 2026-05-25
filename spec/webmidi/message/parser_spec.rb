# frozen_string_literal: true

RSpec.describe Webmidi::Message::Parser do
  describe ".parse_single" do
    it "raises on empty bytes" do
      expect { described_class.parse_single([]) }
        .to raise_error(Webmidi::InvalidMessageError, /Empty/)
    end

    it "raises on invalid status byte" do
      expect { described_class.parse_single([0x00]) }
        .to raise_error(Webmidi::InvalidMessageError)
    end

    it "raises on incomplete NoteOn" do
      expect { described_class.parse_single([0x90, 0x3C]) }
        .to raise_error(Webmidi::InvalidMessageError, /Expected 3 bytes/)
    end

    it "raises on extra bytes in a single message" do
      expect { described_class.parse_single([0x90, 0x3C, 0x64, 0x80]) }
        .to raise_error(Webmidi::InvalidMessageError, /Expected exactly 3 bytes/)
    end

    it "raises on out-of-range bytes" do
      expect { described_class.parse_single([0x90, 0x3C, 256]) }
        .to raise_error(Webmidi::InvalidMessageError, /between 0 and 255/)
    end

    it "raises on invalid system status" do
      expect { described_class.parse_single([0xF4]) }
        .to raise_error(Webmidi::InvalidMessageError)
    end

    it "raises on SysEx without terminator" do
      expect { described_class.parse_single([0xF0, 0x01, 0x02]) }
        .to raise_error(Webmidi::InvalidMessageError, /must end with 0xF7/)
    end

    it "parses all channel message types" do
      expect(described_class.parse_single([0x80, 60, 64])).to be_a(Webmidi::Message::Channel::NoteOff)
      expect(described_class.parse_single([0x90, 60, 100])).to be_a(Webmidi::Message::Channel::NoteOn)
      expect(described_class.parse_single([0xA0, 60, 80])).to be_a(Webmidi::Message::Channel::PolyphonicPressure)
      expect(described_class.parse_single([0xB0, 7, 100])).to be_a(Webmidi::Message::Channel::ControlChange)
      expect(described_class.parse_single([0xC0, 42])).to be_a(Webmidi::Message::Channel::ProgramChange)
      expect(described_class.parse_single([0xD0, 80])).to be_a(Webmidi::Message::Channel::ChannelPressure)
      expect(described_class.parse_single([0xE0, 0, 64])).to be_a(Webmidi::Message::Channel::PitchBend)
    end

    it "parses all system realtime messages" do
      expect(described_class.parse_single([0xF8])).to be_a(Webmidi::Message::System::Clock)
      expect(described_class.parse_single([0xFA])).to be_a(Webmidi::Message::System::Start)
      expect(described_class.parse_single([0xFB])).to be_a(Webmidi::Message::System::Continue)
      expect(described_class.parse_single([0xFC])).to be_a(Webmidi::Message::System::Stop)
      expect(described_class.parse_single([0xFE])).to be_a(Webmidi::Message::System::ActiveSensing)
      expect(described_class.parse_single([0xFF])).to be_a(Webmidi::Message::System::SystemReset)
    end

    it "parses system common messages" do
      expect(described_class.parse_single([0xF1, 0x3A])).to be_a(Webmidi::Message::System::TimeCode)
      expect(described_class.parse_single([0xF2, 0x00, 0x40])).to be_a(Webmidi::Message::System::SongPosition)
      expect(described_class.parse_single([0xF3, 5])).to be_a(Webmidi::Message::System::SongSelect)
      expect(described_class.parse_single([0xF6])).to be_a(Webmidi::Message::System::TuneRequest)
    end

    it "can preserve NoteOn velocity zero" do
      msg = described_class.parse_single([0x90, 60, 0], normalize_note_on_zero: false)
      expect(msg).to be_a(Webmidi::Message::Channel::NoteOn)
      expect(msg.velocity).to eq(0)
    end
  end

  describe ".parse_many" do
    it "parses multiple complete messages" do
      messages = described_class.parse_many([0x90, 60, 100, 0x80, 60, 0])
      expect(messages.map(&:class)).to eq([
        Webmidi::Message::Channel::NoteOn,
        Webmidi::Message::Channel::NoteOff
      ])
    end

    it "dispatches real-time messages immediately while buffering channel messages" do
      messages = described_class.parse_many([0x90, 60, 0xF8, 100])
      expect(messages.map(&:class)).to eq([
        Webmidi::Message::System::Clock,
        Webmidi::Message::Channel::NoteOn
      ])
    end
  end

  describe ".parse_stream" do
    it "supports running status when enabled" do
      messages = described_class.parse_stream([0x90, 60, 100, 61, 110])
      expect(messages.map { |message| [message.note, message.velocity] }).to eq([[60, 100], [61, 110]])
    end

    it "rejects running status in parse_many" do
      expect { described_class.parse_many([0x90, 60, 100, 61, 110]) }
        .to raise_error(Webmidi::InvalidMessageError, /without status/)
    end
  end
end
