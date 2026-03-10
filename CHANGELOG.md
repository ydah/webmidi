# Changelog

## [0.1.0] - 2026-03-10

### Added

- MIDI message classes (NoteOn, NoteOff, ControlChange, ProgramChange, PitchBend, etc.)
- Message parser with running status support
- Pattern matching support for all message types
- Error class hierarchy
- Configuration module
- Transport layer with Virtual and Null implementations
- Port classes (Input, Output, Map) modeled after W3C Web MIDI API
- Access class for device management
- Virtual port and loopback support
- Standard MIDI File reader and writer (Format 0 and 1)
- SMF Event, Track, and Sequence data structures
- Middleware pipeline (Stack, Filter, Transpose, VelocityScale, Logger, Recorder)
- Music theory DSL (Note, Chord, Scale, Rhythm)
- Network MIDI with RTP-MIDI and OSC bridge
- MIDI 2.0 Universal MIDI Packet (UMP) support
- MIDI 1.0 ↔ 2.0 conversion (upgrade/downgrade)
- MIDI Clock with BPM-based tick generation
