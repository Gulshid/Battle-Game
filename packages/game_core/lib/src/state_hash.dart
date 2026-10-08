import 'package:game_core/src/snapshot_codec.dart';
import 'package:game_core/src/state.dart';

/// 32-bit FNV-1a over any byte list. The multiply is written as shifts and
/// adds so the result is identical on the VM and in JavaScript.
int fnv1a32(List<int> bytes) {
  var h = 0x811C9DC5;
  for (final b in bytes) {
    h ^= b;
    h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) &
        0xFFFFFFFF;
  }
  return h;
}

/// Hash of the canonical full snapshot. Client and server compare this every
/// N ticks to detect desync. Events are not part of the hash.
int hashState(WorldState s) {
  return fnv1a32(const SnapshotCodec().encode(s));
}
