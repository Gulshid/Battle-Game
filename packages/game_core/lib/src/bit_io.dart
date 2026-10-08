import 'dart:typed_data';

/// Writes values MSB-first into a compact byte buffer.
///
/// Fixed-width fields (`writeUint` / `writeInt`) are used where the range is
/// known; variable-length integers (`writeVarUint` / `writeVarInt`) where
/// values are usually tiny but unbounded (tick counters, ids).
class BitWriter {
  final List<int> _bytes = <int>[];
  int _cur = 0;
  int _used = 0; // bits already placed in _cur (0..7)

  int get bitLength => _bytes.length * 8 + _used;

  void writeBit(int bit) {
    _cur = (_cur << 1) | (bit & 1);
    _used++;
    if (_used == 8) {
      _bytes.add(_cur);
      _cur = 0;
      _used = 0;
    }
  }

  void writeBool({required bool value}) => writeBit(value ? 1 : 0);

  /// Unsigned integer in exactly [bits] bits (1..32).
  void writeUint(int value, int bits) {
    if (bits < 1 || bits > 32) throw ArgumentError.value(bits, 'bits');
    if (value < 0 || value >= (1 << bits)) {
      throw RangeError('$value does not fit in $bits unsigned bits');
    }
    for (var i = bits - 1; i >= 0; i--) {
      writeBit((value >> i) & 1);
    }
  }

  /// Two's complement signed integer in exactly [bits] bits (2..32).
  void writeInt(int value, int bits) {
    if (bits < 2 || bits > 32) throw ArgumentError.value(bits, 'bits');
    final min = -(1 << (bits - 1));
    final max = (1 << (bits - 1)) - 1;
    if (value < min || value > max) {
      throw RangeError('$value does not fit in $bits signed bits');
    }
    writeUint(value & ((1 << bits) - 1), bits);
  }

  /// 7 bits per byte, high bit = "more follows".
  void writeVarUint(int value) {
    if (value < 0) throw RangeError('$value is negative');
    var v = value;
    while (v >= 0x80) {
      writeUint((v & 0x7F) | 0x80, 8);
      v >>= 7;
    }
    writeUint(v, 8);
  }

  /// Zigzag encoded: small magnitudes stay small for either sign.
  void writeVarInt(int value) =>
      writeVarUint(value >= 0 ? value << 1 : ((-value) << 1) - 1);

  /// Pads the last byte with zero bits.
  Uint8List toBytes() {
    final out = List<int>.of(_bytes);
    if (_used > 0) out.add(_cur << (8 - _used));
    return Uint8List.fromList(out);
  }
}

class BitReader {
  BitReader(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  int get bitsRemaining => _bytes.length * 8 - _pos;

  int readBit() {
    if (_pos >= _bytes.length * 8) {
      throw const FormatException('Unexpected end of data');
    }
    final b = (_bytes[_pos >> 3] >> (7 - (_pos & 7))) & 1;
    _pos++;
    return b;
  }

  bool readBool() => readBit() == 1;

  int readUint(int bits) {
    var v = 0;
    for (var i = 0; i < bits; i++) {
      v = (v << 1) | readBit();
    }
    return v;
  }

  int readInt(int bits) {
    final u = readUint(bits);
    return (u & (1 << (bits - 1))) != 0 ? u - (1 << bits) : u;
  }

  int readVarUint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final b = readUint(8);
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return result;
      shift += 7;
      if (shift > 56) throw const FormatException('Varint too long');
    }
  }

  int readVarInt() {
    final u = readVarUint();
    return (u & 1) == 0 ? u >> 1 : -((u + 1) >> 1);
  }
}
