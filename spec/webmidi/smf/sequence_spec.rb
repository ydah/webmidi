# frozen_string_literal: true

RSpec.describe Webmidi::SMF::Sequence do
  subject(:sequence) { described_class.new(format: 1, ppqn: 480) }

  it "has default format and ppqn" do
    expect(sequence.format).to eq(1)
    expect(sequence.ppqn).to eq(480)
  end

  it "stores tracks" do
    track = Webmidi::SMF::Track.new(name: "Piano")
    sequence.add_track(track)
    expect(sequence.size).to eq(1)
    expect(sequence[0]).to eq(track)
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
end
