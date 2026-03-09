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
  end
end
