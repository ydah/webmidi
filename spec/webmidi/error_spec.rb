# frozen_string_literal: true

RSpec.describe Webmidi::Error do
  it "is a StandardError" do
    expect(Webmidi::Error.new).to be_a(StandardError)
  end
end

RSpec.describe Webmidi::PortNotFoundError do
  it "is a Webmidi::Error" do
    expect(Webmidi::PortNotFoundError.new).to be_a(Webmidi::Error)
  end
end

RSpec.describe Webmidi::InvalidMessageError do
  it "is a Webmidi::Error" do
    expect(Webmidi::InvalidMessageError.new).to be_a(Webmidi::Error)
  end
end

RSpec.describe Webmidi::NetworkError do
  it "is a Webmidi::Error" do
    expect(Webmidi::NetworkError.new).to be_a(Webmidi::Error)
  end
end

RSpec.describe Webmidi::ConnectionTimeoutError do
  it "is a NetworkError" do
    expect(Webmidi::ConnectionTimeoutError.new).to be_a(Webmidi::NetworkError)
  end
end
