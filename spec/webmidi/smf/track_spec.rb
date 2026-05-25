# frozen_string_literal: true

RSpec.describe Webmidi::SMF::Track do
  subject(:track) { described_class.new(name: "Piano") }

  it "stores events" do
    msg = Webmidi::Message.note_on(60, velocity: 100)
    event = Webmidi::SMF::MIDIEvent.new(message: msg, delta_time: 0)
    track << event
    expect(track.size).to eq(1)
  end

  it "is enumerable" do
    msg = Webmidi::Message.note_on(60, velocity: 100)
    track << Webmidi::SMF::MIDIEvent.new(message: msg, delta_time: 0)
    expect(track.count).to eq(1)
  end

  describe "#notes" do
    it "filters note events" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0)
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.control_change(1, 64), delta_time: 0)
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_off(60), delta_time: 480)
      expect(track.notes.count).to eq(2)
    end

    it "pairs note spans" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0)
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_off(60), delta_time: 480)

      span = track.note_spans.first
      expect(span.note).to eq(60)
      expect(span.duration).to eq(480)
    end
  end

  describe "#transpose" do
    it "transposes notes by semitones" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0)
      transposed = track.transpose(5)
      expect(transposed.notes.first.message.note).to eq(65)
    end

    it "clamps to 0-127 range" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(125), delta_time: 0)
      transposed = track.transpose(10)
      expect(transposed.notes.first.message.note).to eq(127)
    end

    it "preserves message timestamps" do
      message = Webmidi::Message.note_on(60)
      track << Webmidi::SMF::MIDIEvent.new(message: message, delta_time: 0)
      transposed = track.transpose(1)
      expect(transposed.notes.first.message.timestamp).to eq(message.timestamp)
    end
  end

  describe "time utilities" do
    it "sorts and recalculates delta times" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_off(60), delta_time: 0, absolute_time: 480)
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0, absolute_time: 0)

      track.recalculate_delta_times!

      expect(track.events.map(&:delta_time)).to eq([0, 480])
    end

    it "quantizes absolute times" do
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), absolute_time: 121)
      track.quantize!(120)
      expect(track.events.first.absolute_time).to eq(120)
    end
  end
end
