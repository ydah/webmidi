# frozen_string_literal: true

require "stringio"

RSpec.describe Webmidi::SMF::Writer do
  describe ".to_binary" do
    it "produces valid SMF binary" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60, velocity: 100),
        delta_time: 0
      )
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_off(60),
        delta_time: 480
      )
      track << Webmidi::SMF::MetaEvent.end_of_track(delta_time: 0)
      seq.add_track(track)

      binary = described_class.to_binary(seq)
      expect(binary[0, 4]).to eq("MThd")
      expect(binary).to include("MTrk")
    end

    it "round-trips through reader" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MetaEvent.tempo(120, delta_time: 0)
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60, velocity: 100),
        delta_time: 0
      )
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_off(60),
        delta_time: 480
      )
      track << Webmidi::SMF::MetaEvent.end_of_track(delta_time: 0)
      seq.add_track(track)

      binary = described_class.to_binary(seq)
      parsed = Webmidi::SMF::Reader.parse(binary)

      expect(parsed.format).to eq(0)
      expect(parsed.ppqn).to eq(480)
      expect(parsed.size).to eq(1)

      midi_events = parsed[0].events.select { |e| e.is_a?(Webmidi::SMF::MIDIEvent) }
      expect(midi_events.size).to eq(2)
      expect(midi_events[0].message.note).to eq(60)
    end

    it "auto-appends end of track if missing" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60),
        delta_time: 0
      )
      seq.add_track(track)

      binary = described_class.to_binary(seq)
      parsed = Webmidi::SMF::Reader.parse(binary)

      last_event = parsed[0].events.last
      expect(last_event).to be_a(Webmidi::SMF::MetaEvent)
      expect(last_event.type).to eq(0x2F)
    end

    it "can write running status" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(60), delta_time: 0)
      track << Webmidi::SMF::MIDIEvent.new(message: Webmidi::Message.note_on(64), delta_time: 0)
      seq.add_track(track)

      binary = described_class.to_binary(seq, running_status: true)
      expect(binary.bytes.each_cons(5).any? { |bytes| bytes == [0x90, 60, 100, 0x00, 64] }).to be true
    end

    it "validates format 0 track count before writing" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      expect { described_class.to_binary(seq) }.to raise_error(Webmidi::InvalidSMFError)
    end

    it "validates VLQ range" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60),
        delta_time: 0x1000_0000
      )
      seq.add_track(track)

      expect { described_class.to_binary(seq) }.to raise_error(Webmidi::InvalidSMFError, /VLQ value/)
    end
  end

  describe ".write" do
    it "writes to IO" do
      seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
      track = Webmidi::SMF::Track.new
      track << Webmidi::SMF::MetaEvent.end_of_track(delta_time: 0)
      seq.add_track(track)

      io = StringIO.new(String.new(encoding: Encoding::ASCII_8BIT))
      described_class.write(seq, io)
      expect(io.string[0, 4]).to eq("MThd")
    end
  end

  describe "multi-track format 1" do
    it "round-trips format 1" do
      seq = Webmidi::SMF::Sequence.new(format: 1, ppqn: 480)

      # Tempo track
      tempo_track = Webmidi::SMF::Track.new
      tempo_track << Webmidi::SMF::MetaEvent.tempo(120, delta_time: 0)
      tempo_track << Webmidi::SMF::MetaEvent.end_of_track(delta_time: 0)
      seq.add_track(tempo_track)

      # Music track
      music_track = Webmidi::SMF::Track.new
      music_track << Webmidi::SMF::MetaEvent.track_name("Piano", delta_time: 0)
      music_track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_on(60, velocity: 100),
        delta_time: 0
      )
      music_track << Webmidi::SMF::MIDIEvent.new(
        message: Webmidi::Message.note_off(60),
        delta_time: 480
      )
      music_track << Webmidi::SMF::MetaEvent.end_of_track(delta_time: 0)
      seq.add_track(music_track)

      binary = described_class.to_binary(seq)
      parsed = Webmidi::SMF::Reader.parse(binary)

      expect(parsed.format).to eq(1)
      expect(parsed.size).to eq(2)

      name_event = parsed[1].events.find { |e| e.is_a?(Webmidi::SMF::MetaEvent) && e.text_event? }
      expect(name_event.text).to eq("Piano")
    end
  end

  describe "generated round-trips" do
    it "round-trips deterministic generated note sequences" do
      random = Random.new(1234)

      10.times do
        seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
        track = Webmidi::SMF::Track.new
        expected = []

        8.times do
          note = random.rand(36..84)
          velocity = random.rand(1..127)
          delta = random.rand(0..120)
          duration = random.rand(1..240)
          on = Webmidi::Message.note_on(note, velocity: velocity)
          off = Webmidi::Message.note_off(note)
          track << Webmidi::SMF::MIDIEvent.new(message: on, delta_time: delta)
          track << Webmidi::SMF::MIDIEvent.new(message: off, delta_time: duration)
          expected << on.to_bytes << off.to_bytes
        end

        seq.add_track(track)
        parsed = Webmidi::SMF::Reader.parse(described_class.to_binary(seq))
        actual = parsed[0].events.grep(Webmidi::SMF::MIDIEvent).map(&:to_bytes)

        expect(actual).to eq(expected)
      end
    end
  end
end
