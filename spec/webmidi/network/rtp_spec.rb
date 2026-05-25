# frozen_string_literal: true

RSpec.describe Webmidi::Network::RTP::Packet do
  describe "round-trip" do
    it "serializes and deserializes a packet" do
      original = described_class.new(
        sequence_number: 42,
        timestamp: 1000,
        ssrc: 12345,
        midi_data: [0x90, 60, 100]
      )

      bytes = original.to_bytes
      parsed = described_class.parse(bytes)

      expect(parsed.sequence_number).to eq(42)
      expect(parsed.timestamp).to eq(1000)
      expect(parsed.ssrc).to eq(12345)
      expect(parsed.midi_data).to eq([0x90, 60, 100])
    end

    it "supports MIDI payloads longer than 255 bytes" do
      original = described_class.new(
        sequence_number: 42,
        timestamp: 1000,
        ssrc: 12345,
        midi_data: [0xF0, *Array.new(260, 0x01), 0xF7]
      )

      parsed = described_class.parse(original.to_bytes)
      expect(parsed.midi_data.size).to eq(262)
    end
  end

  describe ".parse" do
    it "returns nil for too-short data" do
      expect(described_class.parse("short")).to be_nil
    end

    it "returns nil for invalid RTP MIDI payload type" do
      bytes = described_class.new(sequence_number: 1, timestamp: 2, ssrc: 3, midi_data: [0xF8]).to_bytes
      bytes.setbyte(1, 98)
      expect(described_class.parse(bytes)).to be_nil
    end

    it "returns nil for length mismatches" do
      bytes = described_class.new(sequence_number: 1, timestamp: 2, ssrc: 3, midi_data: [0xF8]).to_bytes
      expect(described_class.parse(bytes[0...-1])).to be_nil
    end

    it "validates packet fields" do
      expect do
        described_class.new(sequence_number: -1, timestamp: 0, ssrc: 0, midi_data: [0xF8])
      end.to raise_error(Webmidi::InvalidMessageError)
    end
  end
end

RSpec.describe Webmidi::Network::RTP::ControlPacket do
  it "round-trips AppleMIDI invitations" do
    packet = described_class.invitation(token: 123, ssrc: 456, name: "Client")
    parsed = described_class.parse(packet.to_bytes)

    expect(parsed.command).to eq(:invitation)
    expect(parsed.version).to eq(described_class::PROTOCOL_VERSION)
    expect(parsed.token).to eq(123)
    expect(parsed.ssrc).to eq(456)
    expect(parsed.name).to eq("Client")
  end

  it "round-trips synchronization packets" do
    packet = described_class.synchronization(ssrc: 456, count: 1, timestamps: [10, 20, 30])
    parsed = described_class.parse(packet.to_bytes)

    expect(parsed.command).to eq(:synchronization)
    expect(parsed.count).to eq(1)
    expect(parsed.timestamps).to eq([10, 20, 30])
  end

  it "round-trips receiver feedback and end-session packets" do
    feedback = described_class.parse(described_class.receiver_feedback(ssrc: 456, sequence_number: 42).to_bytes)
    bye = described_class.parse(described_class.end_session(ssrc: 456).to_bytes)

    expect(feedback.sequence_number).to eq(42)
    expect(bye.command).to eq(:end_session)
  end

  it "validates fixed-width fields before packing" do
    expect { described_class.invitation(token: -1, ssrc: 456, name: "Client") }
      .to raise_error(Webmidi::InvalidMessageError, /Initiator token/)
  end
end

RSpec.describe Webmidi::Network::RTP::Session do
  let(:session) { Webmidi::Network::RTP.server(port: 0, name: "Test") }

  after { session.close }

  it "can be created as server" do
    expect(session.name).to eq("Test")
    session.start
    expect(session.port).to be > 0
  end

  it "manages peers without duplicates" do
    session.add_peer("127.0.0.1", 5004)
    session.add_peer("127.0.0.1", 5004)
    expect(session.peers).to eq([{host: "127.0.0.1", port: 5004}])

    session.remove_peer("127.0.0.1", 5004)
    expect(session.peers).to be_empty
  end

  it "validates raw outgoing MIDI byte arrays" do
    expect { session.send([0x90, 60]) }
      .to raise_error(Webmidi::InvalidMessageError)
  end

  it "accepts arrays of MIDI messages for outgoing packets" do
    expect do
      session.send([Webmidi::Message.note_on(60), Webmidi::Message.note_off(60)])
    end.not_to raise_error
  end

  it "receives multiple MIDI messages from one packet" do
    received = []
    session.on_message { |message| received << message }
    session.start

    packet = Webmidi::Network::RTP::Packet.new(
      sequence_number: 1,
      timestamp: 1234,
      ssrc: 99,
      midi_data: [0x90, 60, 100, 0x80, 60, 0]
    )
    UDPSocket.new.send(packet.to_bytes, 0, "127.0.0.1", session.port)
    sleep 0.1

    expect(received.map(&:class)).to eq([
      Webmidi::Message::Channel::NoteOn,
      Webmidi::Message::Channel::NoteOff
    ])
    expect(received.first.timestamp).to eq(1234)
  end

  it "reports receive parse errors" do
    errors = []
    session.on_error { |error, _data| errors << error }
    session.start

    packet = Webmidi::Network::RTP::Packet.new(
      sequence_number: 1,
      timestamp: 1234,
      ssrc: 99,
      midi_data: [0x90, 60]
    )
    UDPSocket.new.send(packet.to_bytes, 0, "127.0.0.1", session.port)
    sleep 0.1

    expect(errors.first).to be_a(Webmidi::InvalidMessageError)
  end
end

RSpec.describe Webmidi::Network::AppleMIDI::Session do
  def wait_until(timeout: 1.0)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "timed out waiting for condition" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  let(:server) { Webmidi::Network::AppleMIDI.server(port: 0, name: "Server") }
  let(:client) { Webmidi::Network::AppleMIDI.server(port: 0, name: "Client") }

  after do
    client.close
    server.close
  end

  it "negotiates control and data invitations before sending RTP MIDI" do
    received = []
    server.start
    client.start
    server.on_message { |message| received << message }

    client.connect_to("127.0.0.1", server.control_port, data_port: server.data_port)

    wait_until { client.peers.any? && server.peers.any? }
    client.send(Webmidi::Message.note_on(60, velocity: 100))
    wait_until { received.any? }

    expect(received.first).to be_a(Webmidi::Message::Channel::NoteOn)
    expect(received.first.note).to eq(60)
  end
end
