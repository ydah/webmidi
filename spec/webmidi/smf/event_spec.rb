# frozen_string_literal: true

RSpec.describe Webmidi::SMF::MIDIEvent do
  it "wraps a MIDI message" do
    msg = Webmidi::Message.note_on(60, velocity: 100)
    event = described_class.new(message: msg, delta_time: 480)
    expect(event.message).to eq(msg)
    expect(event.delta_time).to eq(480)
    expect(event.to_bytes).to eq([0x90, 60, 100])
  end
end

RSpec.describe Webmidi::SMF::MetaEvent do
  describe ".tempo" do
    it "creates a tempo meta event" do
      event = described_class.tempo(120)
      expect(event.type).to eq(0x51)
      expect(event.bpm).to be_within(0.01).of(120.0)
    end

    it "round-trips tempo" do
      event = described_class.tempo(140)
      expect(event.bpm).to be_within(0.01).of(140.0)
    end
  end

  describe ".track_name" do
    it "creates a track name event" do
      event = described_class.track_name("Piano")
      expect(event.text).to eq("Piano")
      expect(event.text_event?).to be true
    end
  end

  describe ".end_of_track" do
    it "creates an end of track event" do
      event = described_class.end_of_track
      expect(event.type).to eq(0x2F)
    end
  end

  describe ".time_signature" do
    it "creates a time signature event" do
      event = described_class.time_signature(numerator: 3, denominator: 4)
      expect(event.type).to eq(0x58)
      expect(event.data[0]).to eq(3)
    end
  end
end

RSpec.describe Webmidi::SMF::SysExEvent do
  it "wraps sysex data" do
    event = described_class.new(data: [0x7E, 0x7F], delta_time: 0)
    expect(event.to_bytes).to eq([0xF0, 0x7E, 0x7F, 0xF7])
  end
end
