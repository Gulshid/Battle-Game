import 'dart:typed_data';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  test('fixed-width round trip', () {
    final w = BitWriter()
      ..writeUint(5, 3)
      ..writeInt(-3, 4)
      ..writeBool(value: true)
      ..writeUint(0xFFFFFFFF, 32)
      ..writeInt(-2147483648, 32);
    final r = BitReader(w.toBytes());
    expect(r.readUint(3), 5);
    expect(r.readInt(4), -3);
    expect(r.readBool(), isTrue);
    expect(r.readUint(32), 0xFFFFFFFF);
    expect(r.readInt(32), -2147483648);
  });

  test('bit length is exact and bytes are padded', () {
    final w = BitWriter()..writeUint(1, 5);
    expect(w.bitLength, 5);
    expect(w.toBytes().length, 1);
    w.writeUint(0, 8);
    expect(w.bitLength, 13);
    expect(w.toBytes().length, 2);
  });

  test('varints are small for small values', () {
    final w = BitWriter()
      ..writeVarUint(5)
      ..writeVarUint(300)
      ..writeVarInt(-1)
      ..writeVarInt(1);
    expect(w.bitLength, 8 + 16 + 8 + 8);
    final r = BitReader(w.toBytes());
    expect(r.readVarUint(), 5);
    expect(r.readVarUint(), 300);
    expect(r.readVarInt(), -1);
    expect(r.readVarInt(), 1);
  });

  test('random mixed sequence survives a round trip', () {
    final rng = Rng(2024);
    final ops = <({int kind, int bits, int value})>[];
    final w = BitWriter();
    for (var i = 0; i < 500; i++) {
      final kind = rng.nextInt(4);
      final bits = rng.range(2, 32);
      late int value;
      switch (kind) {
        case 0:
          value = rng.nextU32() & ((1 << bits) - 1);
          w.writeUint(value, bits);
        case 1:
          final u = rng.nextU32() & ((1 << bits) - 1);
          value = u >= (1 << (bits - 1)) ? u - (1 << bits) : u;
          w.writeInt(value, bits);
        case 2:
          value = rng.nextU32() >> rng.nextInt(32);
          w.writeVarUint(value);
        default:
          final mag = rng.nextU32() >> rng.nextInt(32);
          value = rng.chance(50) ? mag : -mag;
          w.writeVarInt(value);
      }
      ops.add((kind: kind, bits: bits, value: value));
    }
    final r = BitReader(w.toBytes());
    for (final op in ops) {
      final got = switch (op.kind) {
        0 => r.readUint(op.bits),
        1 => r.readInt(op.bits),
        2 => r.readVarUint(),
        _ => r.readVarInt(),
      };
      expect(got, op.value);
    }
  });

  test('out of range values are rejected', () {
    expect(() => BitWriter().writeUint(256, 8), throwsRangeError);
    expect(() => BitWriter().writeUint(-1, 8), throwsRangeError);
    expect(() => BitWriter().writeInt(128, 8), throwsRangeError);
    expect(() => BitWriter().writeInt(-129, 8), throwsRangeError);
    expect(() => BitWriter().writeVarUint(-1), throwsRangeError);
  });

  test('reading past the end throws', () {
    final r = BitReader(Uint8List(1));
    r.readUint(8);
    expect(r.readBit, throwsFormatException);
  });
}
