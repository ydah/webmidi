# frozen_string_literal: true

RSpec.describe Webmidi::Port::Base do
  let(:handle) { Webmidi::Transport::Virtual.create_virtual_input("Test") }

  after { Webmidi::Transport::Virtual.reset! }

  subject(:port) do
    described_class.new(
      id: "test-1",
      name: "Test Port",
      manufacturer: "Test",
      version: "1.0",
      type: :input,
      transport_handle: handle
    )
  end

  describe "#open / #close" do
    it "starts closed" do
      expect(port).not_to be_open
      expect(port.state).to eq(:connected)
      expect(port.connection).to eq(:closed)
    end

    it "can be opened" do
      port.open
      expect(port).to be_open
      expect(port.connection).to eq(:open)
    end

    it "can be closed" do
      port.open
      port.close
      expect(port).not_to be_open
      expect(port.state).to eq(:connected)
    end

    it "can be reopened after closing the connection" do
      port.open
      port.close
      port.open
      expect(port).to be_open
      expect(handle).not_to be_closed
    end

    it "cannot be opened after disconnecting the device" do
      port.disconnect
      expect { port.open }.to raise_error(Webmidi::PortClosedError, /disconnected/)
    end
  end

  describe "#on_state_change" do
    it "notifies on open" do
      connections = []
      port.on_state_change { |p| connections << p.connection }
      port.open
      expect(connections).to eq([:open])
    end

    it "can unsubscribe" do
      connections = []
      subscription = port.on_state_change { |p| connections << p.connection }
      subscription.unsubscribe
      port.open
      expect(connections).to be_empty
    end
  end
end

RSpec.describe Webmidi::Port::Output do
  let(:output_handle) { Webmidi::Transport::Virtual.create_virtual_output("Test Output") }

  after { Webmidi::Transport::Virtual.reset! }

  subject(:port) do
    described_class.new(
      id: "out-1",
      name: "Test Output",
      manufacturer: "Test",
      version: "1.0",
      transport_handle: output_handle
    )
  end

  describe "#send" do
    it "sends a Message object" do
      msg = Webmidi::Message.note_on(60, velocity: 100)
      port.send(msg)
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100]])
    end

    it "sends raw bytes" do
      port.send([0x90, 60, 100])
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100]])
    end

    it "validates raw bytes" do
      expect { port.send([0x90, 60]) }.to raise_error(Webmidi::InvalidMessageError)
    end

    it "sends multiple raw messages without flattening message arguments" do
      port.send([0x90, 60, 100, 0x80, 60, 0])
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100], [0x80, 60, 0]])
    end

    it "can send again after close reopens the connection" do
      port.send(Webmidi::Message.note_on(60))
      port.close
      port.send(Webmidi::Message.note_on(61))
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100], [0x90, 61, 100]])
    end

    it "sends scheduled messages after their timestamp" do
      timestamp = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.03
      port.send(Webmidi::Message.note_on(60), timestamp: timestamp)
      expect(output_handle.sent_messages).to be_empty
      sleep 0.06
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100]])
      port.close
    end

    it "clears scheduled messages" do
      timestamp = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.04
      port.send(Webmidi::Message.note_on(60), timestamp: timestamp)
      port.clear
      sleep 0.06
      expect(output_handle.sent_messages).to be_empty
      port.close
    end

    it "rejects SysEx unless enabled" do
      expect { port.send(Webmidi::Message.sysex(0x7E)) }
        .to raise_error(Webmidi::SysExNotPermittedError)
    end

    it "sends SysEx when enabled" do
      sysex_port = described_class.new(
        id: "out-sysex",
        name: "Test Output",
        manufacturer: "Test",
        version: "1.0",
        transport_handle: output_handle,
        sysex_enabled: true
      )
      sysex_port.send(Webmidi::Message.sysex(0x7E))
      expect(output_handle.sent_messages).to eq([[0xF0, 0x7E, 0xF7]])
    end
  end

  describe "#note_on" do
    it "sends a NoteOn message" do
      port.note_on(60, velocity: 100)
      expect(output_handle.sent_messages.first).to eq([0x90, 60, 100])
    end
  end

  describe "#note_off" do
    it "sends a NoteOff message" do
      port.note_off(60)
      expect(output_handle.sent_messages.first).to eq([0x80, 60, 0])
    end
  end

  describe "#<<" do
    it "sends via pipe operator" do
      port << Webmidi::Message.note_on(60)
      expect(output_handle.sent_messages).not_to be_empty
    end
  end

  describe "#send_all" do
    it "sends arrays of messages as messages, not flattened bytes" do
      port.send_all([Webmidi::Message.note_on(60), Webmidi::Message.note_off(60)])
      expect(output_handle.sent_messages).to eq([[0x90, 60, 100], [0x80, 60, 0]])
    end
  end

  describe "#use" do
    it "applies middleware before sending" do
      port.use(Webmidi::Middleware::Transpose, semitones: 2)
      port.note_on(60)
      expect(output_handle.sent_messages).to eq([[0x90, 62, 100]])
    end

    it "drops messages when middleware returns nil" do
      stack = Webmidi::Middleware::Stack.new do
        use Webmidi::Middleware::NoteRangeFilter, min: 70, max: 80
      end
      port.use(stack)
      port.note_on(60)
      expect(output_handle.sent_messages).to be_empty
    end

    it "sends message arrays returned by middleware without flattening bytes" do
      stack = Webmidi::Middleware::Stack.new do
        use Webmidi::Middleware::Panic, channels: 0, controls: [:all_notes_off]
      end
      port.use(stack)

      port.send(Webmidi::Message.system_reset)

      expect(output_handle.sent_messages).to eq([[0xB0, 123, 0]])
    end
  end

  describe "#all_notes_off" do
    it "sends CC 123 on specified channel" do
      port.all_notes_off(channel: 0)
      expect(output_handle.sent_messages.first).to eq([0xB0, 123, 0])
    end

    it "sends CC 123 on all channels when no channel specified" do
      port.all_notes_off
      expect(output_handle.sent_messages.size).to eq(16)
    end
  end
end

RSpec.describe Webmidi::Port::Input do
  let(:input_handle) { Webmidi::Transport::Virtual.create_virtual_input("Test Input") }

  after { Webmidi::Transport::Virtual.reset! }

  subject(:port) do
    described_class.new(
      id: "in-1",
      name: "Test Input",
      manufacturer: "Test",
      version: "1.0",
      transport_handle: input_handle
    )
  end

  describe "#dispatch" do
    it "dispatches to on_message callbacks" do
      received = []
      port.on_message { |msg| received << msg }
      port.dispatch([0x90, 60, 100])
      expect(received.first).to be_a(Webmidi::Message::Channel::NoteOn)
    end

    it "dispatches to typed callbacks" do
      notes = []
      port.on_note_on { |msg| notes << msg.note }
      port.dispatch([0x90, 60, 100])
      expect(notes).to eq([60])
    end

    it "dispatches typed callbacks by superclass" do
      received = []
      port.on_type(Webmidi::Message::Channel::Base) { |msg| received << msg.class }
      port.dispatch([0x90, 60, 100])
      expect(received).to eq([Webmidi::Message::Channel::NoteOn])
    end

    it "can unsubscribe message callbacks" do
      received = []
      subscription = port.on_message { |msg| received << msg }
      subscription.unsubscribe
      port.dispatch([0x90, 60, 100])
      expect(received).to be_empty
    end

    it "reports parse errors without raising by default" do
      errors = []
      port.on_error { |error, bytes| errors << [error.class, bytes] }
      expect { port.dispatch([0x90, 60]) }.not_to raise_error
      expect(errors).to eq([[Webmidi::InvalidMessageError, [0x90, 60]]])
    end

    it "masks SysEx when not enabled" do
      received = []
      port.on_message { |msg| received << msg }
      port.dispatch([0xF0, 0x7E, 0xF7])
      expect(received).to be_empty
    end

    it "dispatches SysEx when enabled" do
      sysex_port = described_class.new(
        id: "in-sysex",
        name: "Test Input",
        manufacturer: "Test",
        version: "1.0",
        transport_handle: input_handle,
        sysex_enabled: true
      )
      received = []
      sysex_port.on_sysex { |msg| received << msg }
      sysex_port.dispatch([0xF0, 0x7E, 0xF7])
      expect(received.first).to be_a(Webmidi::Message::System::SysEx)
    end

    it "does not dispatch when closed" do
      received = []
      port.on_message { |msg| received << msg }
      port.close
      port.dispatch([0x90, 60, 100])
      expect(received).to be_empty
    end
  end

  describe "#pipe" do
    it "pipes input messages through middleware to an output" do
      output_handle = Webmidi::Transport::Virtual.create_virtual_output("Pipe Output")
      output = Webmidi::Port::Output.new(
        id: "pipe-out",
        name: "Pipe Output",
        manufacturer: "Test",
        version: "1.0",
        transport_handle: output_handle
      )
      stack = Webmidi::Middleware::Stack.new do
        use Webmidi::Middleware::Transpose, semitones: 1
      end

      subscription = port.pipe(stack).to(output)
      port.dispatch([0x90, 60, 100])

      expect(output_handle.sent_messages).to eq([[0x90, 61, 100]])
      subscription.unsubscribe
    end
  end
end

RSpec.describe Webmidi::Port::Map do
  let(:port1) do
    Webmidi::Port::Base.new(
      id: "p1", name: "Port 1", manufacturer: "Test",
      version: "1.0", type: :input,
      transport_handle: nil
    )
  end

  let(:port2) do
    Webmidi::Port::Base.new(
      id: "p2", name: "Port 2", manufacturer: "Test",
      version: "1.0", type: :input,
      transport_handle: nil
    )
  end

  subject(:map) { described_class.new([port1, port2]) }

  it "looks up by id" do
    expect(map["p1"]).to eq(port1)
  end

  it "looks up by name" do
    expect(map["Port 2"]).to eq(port2)
  end

  it "is enumerable" do
    expect(map.to_a.size).to eq(2)
  end

  it "reports size" do
    expect(map.size).to eq(2)
  end

  it "can add ports" do
    new_map = described_class.new
    new_map.add(port1)
    expect(new_map.size).to eq(1)
  end

  it "can create read-only snapshots" do
    snapshot = map.snapshot
    expect(snapshot.to_a).to eq([port1, port2])
    expect { snapshot.add(port1) }.to raise_error(FrozenError)
  end
end
