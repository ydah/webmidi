# Webmidi

Webmidi is a pure-Ruby MIDI library inspired by the W3C Web MIDI API.
It provides MIDI messages, ports, Standard MIDI File I/O, middleware,
network MIDI, and MIDI 2.0 UMP support with zero runtime dependencies.

## Requirements

- Ruby 3.2 or newer

## Installation

```ruby
gem "webmidi"
```

## Quick Start

```ruby
require "webmidi"

loopback = Webmidi::Virtual::Loopback.create(name: "Demo")

loopback.input.on_message do |message|
  puts message.to_hex
end

loopback.output.note_on(60, velocity: 100)
loopback.output.note_off(60)

loopback.close
```

## Core APIs

```ruby
# MIDI messages
message = Webmidi::Message.note_on(:C4, velocity: 100, channel: 0)
message.to_bytes # => [0x90, 60, 100]

parsed = Webmidi::Message.from_bytes(0x90, 60, 100)

# Standard MIDI Files
sequence = Webmidi::SMF::Sequence.read("input.mid")
sequence.write("output.mid")

# MIDI 2.0 UMP
ump = Webmidi::Message.upgrade(message)
midi1 = Webmidi::Message.downgrade(ump)
```

## Included

- MIDI 1.0 channel and system messages
- MIDI byte parsing, stream parsing, and running status support
- Virtual input/output ports and loopback ports
- Standard MIDI File format 0/1 reader and writer
- Middleware for filtering, transposition, velocity changes, logging, recording, and routing
- Music helpers for notes, chords, scales, rhythm, and frequencies
- RTP-MIDI, AppleMIDI negotiation, and OSC bridging
- MIDI 2.0 Universal MIDI Packet parsing and MIDI 1.0 conversion

## Development

```bash
bundle install
bundle exec rake spec
bundle exec rake release:check
```

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
