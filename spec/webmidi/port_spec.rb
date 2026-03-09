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
    end

    it "can be opened" do
      port.open
      expect(port).to be_open
    end

    it "can be closed" do
      port.open
      port.close
      expect(port).not_to be_open
    end
  end

  describe "#on_state_change" do
    it "notifies on open" do
      states = []
      port.on_state_change { |p| states << p.state }
      port.open
      expect(states).to eq([:open])
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

    it "does not dispatch when closed" do
      received = []
      port.on_message { |msg| received << msg }
      port.close
      port.dispatch([0x90, 60, 100])
      expect(received).to be_empty
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
end
