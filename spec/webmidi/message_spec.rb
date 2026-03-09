# frozen_string_literal: true

RSpec.describe Webmidi::Message do
  describe ".note_on" do
    it "creates a NoteOn message" do
      msg = described_class.note_on(60, velocity: 100, channel: 0)
      expect(msg).to be_a(Webmidi::Message::Channel::NoteOn)
      expect(msg.note).to eq(60)
      expect(msg.velocity).to eq(100)
      expect(msg.channel).to eq(0)
    end
  end

  describe ".note_off" do
    it "creates a NoteOff message" do
      msg = described_class.note_off(60)
      expect(msg).to be_a(Webmidi::Message::Channel::NoteOff)
      expect(msg.note).to eq(60)
      expect(msg.velocity).to eq(0)
    end
  end

  describe ".control_change" do
    it "creates a ControlChange message" do
      msg = described_class.control_change(1, 64, channel: 2)
      expect(msg).to be_a(Webmidi::Message::Channel::ControlChange)
      expect(msg.cc).to eq(1)
      expect(msg.value).to eq(64)
      expect(msg.channel).to eq(2)
    end
  end

  describe ".program_change" do
    it "creates a ProgramChange message" do
      msg = described_class.program_change(42)
      expect(msg).to be_a(Webmidi::Message::Channel::ProgramChange)
      expect(msg.program).to eq(42)
    end
  end

  describe ".pitch_bend" do
    it "creates a PitchBend message" do
      msg = described_class.pitch_bend(8192, channel: 1)
      expect(msg).to be_a(Webmidi::Message::Channel::PitchBend)
      expect(msg.value).to eq(8192)
    end
  end

  describe ".sysex" do
    it "creates a SysEx message" do
      msg = described_class.sysex(0x7E, 0x7F, 0x09, 0x01)
      expect(msg).to be_a(Webmidi::Message::System::SysEx)
      expect(msg.data).to eq([0x7E, 0x7F, 0x09, 0x01])
    end
  end

  describe ".clock" do
    it "creates a Clock message" do
      msg = described_class.clock
      expect(msg).to be_a(Webmidi::Message::System::Clock)
    end
  end

  describe ".from_bytes" do
    it "parses NoteOn bytes" do
      msg = described_class.from_bytes(0x90, 0x3C, 0x64)
      expect(msg).to be_a(Webmidi::Message::Channel::NoteOn)
      expect(msg.note).to eq(60)
      expect(msg.velocity).to eq(100)
    end

    it "parses NoteOn with zero velocity as NoteOff" do
      msg = described_class.from_bytes(0x90, 0x3C, 0x00)
      expect(msg).to be_a(Webmidi::Message::Channel::NoteOff)
    end

    it "parses SysEx bytes" do
      msg = described_class.from_bytes(0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7)
      expect(msg).to be_a(Webmidi::Message::System::SysEx)
      expect(msg.data).to eq([0x7E, 0x7F, 0x09, 0x01])
    end

    it "accepts an array" do
      msg = described_class.from_bytes([0xF8])
      expect(msg).to be_a(Webmidi::Message::System::Clock)
    end
  end
end
