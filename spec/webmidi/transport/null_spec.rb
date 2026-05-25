# frozen_string_literal: true

RSpec.describe Webmidi::Transport::Null do
  describe ".available?" do
    it "returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe ".list_inputs / .list_outputs" do
    it "returns empty arrays" do
      expect(described_class.list_inputs).to eq([])
      expect(described_class.list_outputs).to eq([])
    end

    it "creates unique virtual handle ids" do
      first = described_class.create_virtual_input("Null In")
      second = described_class.create_virtual_input("Null In")
      expect(first.device_info.id).not_to eq(second.device_info.id)
    end
  end

  describe "NullOutputHandle" do
    it "records sent messages" do
      handle = described_class.create_virtual_output("Null Out")
      handle.write([0x90, 60, 100])
      expect(handle.sent_messages).to eq([[0x90, 60, 100]])
    end
  end
end
