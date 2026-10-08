import 'package:flutter_test/flutter_test.dart';
import 'package:game_client/shared/pool.dart';

void main() {
  test('pool reuses objects', () {
    final p = Pool<List<int>>(() => [], (l) => l.clear(), prewarm: 2);
    final a = p.acquire();
    p.release(a);
    expect(identical(p.acquire(), a), isTrue);
  });
}
