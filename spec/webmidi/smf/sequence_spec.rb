# frozen_string_literal: true

RSpec.describe Webmidi::SMF::Sequence do
  subject(:sequence) { described_class.new(format: 1, ppqn: 480) }

  it "has default format and ppqn" do
    expect(sequence.format).to eq(1)
    expect(sequence.ppqn).to eq(480)
  end

  it "validates format and ppqn" do
    expect { described_class.new(format: 2) }.to raise_error(Webmidi::UnsupportedFormatError)
    expect { described_class.new(ppqn: 0) }.to raise_error(Webmidi::InvalidSMFError)
  end

  it "stores tracks" do
    track = Webmidi::SMF::Track.new(name: "Piano")
    sequence.add_track(track)
    expect(sequence.size).to eq(1)
    expect(sequence[0]).to eq(track)
  end

  it "enforces format 0 track count" do
    seq = described_class.new(format: 0)
    seq.add_track(Webmidi::SMF::Track.new)
    expect { seq.add_track(Webmidi::SMF::Track.new) }.to raise_error(Webmidi::InvalidSMFError)
  end

  it "is enumerable" do
    sequence.add_track(Webmidi::SMF::Track.new)
    expect(sequence.count).to eq(1)
  end

  describe "#duration" do
    it "calculates duration from tempo and ticks" do
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MetaEvent.tempo(120)
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60),
        delta_time: 960
      )
      sequence.add_track(track)

      # 960 ticks at 480 ppqn, 120 BPM = 1 second
      expect(sequence.duration).to be_within(0.01).of(1.0)
    end

    it "returns 0 for empty sequence" do
      expect(sequence.duration).to eq(0.0)
    end
  end

  describe "#tempo_map" do
    it "converts between ticks and seconds" do
      map = sequence.tempo_map
      expect(map.ticks_to_seconds(480)).to eq(0.5)
      expect(map.seconds_to_ticks(0.5)).to eq(480)
    end
  end

  describe "#to_format0 / #to_format1" do
    it "merges tracks into format 0" do
      first = Webmidi::SMF::Track.new
      second = Webmidi::SMF::Track.new
      first << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0)
      second << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(64), delta_time: 240)
      sequence.add_track(first)
      sequence.add_track(second)

      converted = sequence.to_format0

      expect(converted.format).to eq(0)
      expect(converted.size).to eq(1)
      expect(converted[0].events.map(&:delta_time)).to eq([0, 240])
    end

    it "copies tracks into format 1" do
      sequence.add_track(Webmidi::SMF::Track.new)
      expect(sequence.to_format1.format).to eq(1)
    end
  end
end
