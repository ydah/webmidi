# frozen_string_literal: true

RSpec.describe Webmidi::SMF::Reader do
  def build_midi_binary(format: 1, num_tracks: 1, ppqn: 480, tracks: [])
    data = String.new(encoding: Encoding::ASCII_8BIT)
    # Header
    data << "MThd"
    data << [6].pack("N")
    data << [format, num_tracks, ppqn].pack("nnn")
    # Tracks
    tracks.each do |track_bytes|
      data << "MTrk"
      data << [track_bytes.bytesize].pack("N")
      data << track_bytes
    end
    data
  end

  def vlq(value)
    bytes = [value & 0x7F]
    value >>= 7
    while value > 0
      bytes.unshift((value & 0x7F) | 0x80)
      value >>= 7
    end
    bytes.pack("C*")
  end

  describe ".parse" do
    it "parses a minimal SMF" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      # Delta 0, NoteOn ch0 C4 vel100
      track_data << vlq(0) << [0x90, 60, 100].pack("C*")
      # Delta 480, NoteOff ch0 C4 vel0
      track_data << vlq(480) << [0x80, 60, 0].pack("C*")
      # End of track
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")

      binary = build_midi_binary(format: 0, num_tracks: 1, ppqn: 480, tracks: [track_data])
      seq = described_class.parse(binary)

      expect(seq.format).to eq(0)
      expect(seq.ppqn).to eq(480)
      expect(seq.size).to eq(1)
      expect(seq[0].size).to eq(3)
    end

    it "parses meta events" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      # Track name
      name = "Piano"
      track_data << vlq(0) << [0xFF, 0x03].pack("C*") << vlq(name.bytesize) << name
      # Tempo (120 BPM = 500000 microseconds)
      track_data << vlq(0) << [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20].pack("C*")
      # End of track
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")

      binary = build_midi_binary(tracks: [track_data])
      seq = described_class.parse(binary)

      events = seq[0].events
      expect(events[0]).to be_a(Webmidi::SMF::MetaEvent)
      expect(events[0].text).to eq("Piano")
      expect(events[1].bpm).to be_within(0.01).of(120.0)
    end

    it "handles running status" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      # NoteOn with status
      track_data << vlq(0) << [0x90, 60, 100].pack("C*")
      # NoteOn without status (running status)
      track_data << vlq(0) << [64, 100].pack("C*")
      # End of track
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")

      binary = build_midi_binary(tracks: [track_data])
      seq = described_class.parse(binary)

      events = seq[0].events.select { |e| e.is_a?(Webmidi::SMF::MIDIEvent) }
      expect(events.size).to eq(2)
      expect(events[0].message.note).to eq(60)
      expect(events[1].message.note).to eq(64)
    end

    it "raises on invalid header" do
      expect { described_class.parse("INVALID") }
        .to raise_error(Webmidi::InvalidSMFError)
    end

    it "parses VLQ correctly" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      # Delta time 128 (VLQ: 0x81 0x00)
      track_data << [0x81, 0x00].pack("C*") << [0x90, 60, 100].pack("C*")
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")

      binary = build_midi_binary(tracks: [track_data])
      seq = described_class.parse(binary)
      expect(seq[0].events.first.delta_time).to eq(128)
    end

    it "rejects VLQ longer than 4 bytes" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      track_data << [0x81, 0x81, 0x81, 0x81, 0x00].pack("C*") << [0xFF, 0x2F, 0x00].pack("C*")
      binary = build_midi_binary(tracks: [track_data])

      expect { described_class.parse(binary) }.to raise_error(Webmidi::InvalidSMFError, /VLQ exceeds 4 bytes/)
    end

    it "skips unknown chunks before tracks" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")
      binary = String.new(encoding: Encoding::ASCII_8BIT)
      binary << "MThd" << [6].pack("N") << [1, 1, 480].pack("nnn")
      binary << "JUNK" << [4].pack("N") << "skip"
      binary << "MTrk" << [track_data.bytesize].pack("N") << track_data

      expect(described_class.parse(binary).size).to eq(1)
    end

    it "stops at end of track and skips trailing bytes" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")
      track_data << vlq(0) << [0x90, 60, 100].pack("C*")
      binary = build_midi_binary(tracks: [track_data])

      seq = described_class.parse(binary)
      expect(seq[0].events.size).to eq(1)
    end

    it "enforces track chunk boundaries" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      track_data << vlq(0) << [0x90, 60].pack("C*")
      binary = build_midi_binary(tracks: [track_data])

      expect { described_class.parse(binary) }.to raise_error(Webmidi::InvalidSMFError)
    end
  end

  describe ".read" do
    it "reads from IO" do
      track_data = String.new(encoding: Encoding::ASCII_8BIT)
      track_data << vlq(0) << [0xFF, 0x2F, 0x00].pack("C*")
      binary = build_midi_binary(tracks: [track_data])

      io = StringIO.new(binary)
      seq = described_class.read(io)
      expect(seq).to be_a(Webmidi::SMF::Sequence)
    end
  end
end
