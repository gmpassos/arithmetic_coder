import 'dart:math';

import 'package:arithmetic_coder/src/fenwick.dart';
import 'package:test/test.dart';

/// Asserts the core Fenwick invariants that must hold after *any* sequence of
/// operations (including rescale):
/// - `sum(i)` equals the running prefix sum of `freqOf`.
/// - `total` equals the full prefix sum.
/// - `toFrequencyList` matches `freqOf` for every symbol.
/// - `findWithLow` / `findByCumulative` agree with the cumulative layout.
void _checkInvariants(Fenwick f) {
  var running = 0;
  for (var i = 0; i < f.size; i++) {
    running += f.freqOf(i);
    expect(
      f.sum(i),
      equals(running),
      reason: 'sum($i) must equal prefix sum of freqOf up to $i',
    );
  }

  expect(f.total, equals(running), reason: 'total must equal full prefix sum');
  expect(f.toFrequencyList(), equals(_freqList(f)));

  // findWithLow / findByCumulative over the whole cumulative range.
  for (var v = 0; v < f.total; v++) {
    final (symbol, low) = f.findWithLow(v);

    expect(
      f.findByCumulative(v),
      equals(symbol),
      reason: 'findWithLow and findByCumulative must agree at value $v',
    );
    expect(
      low,
      equals(symbol > 0 ? f.sum(symbol - 1) : 0),
      reason: 'low must equal sum(symbol - 1) at value $v',
    );
    expect(
      v,
      inInclusiveRange(low, low + f.freqOf(symbol) - 1),
      reason: 'value $v must fall inside [low, low + freq) of its symbol',
    );
  }
}

List<int> _freqList(Fenwick f) => [
  for (var i = 0; i < f.size; i++) f.freqOf(i),
];

void main() {
  group('Fenwick.init', () {
    test('sets every frequency to 1 and total to size', () {
      final f = Fenwick(32, 16);
      expect(f.init(), equals(16));

      expect(f.total, equals(16));
      expect(_freqList(f), equals(List.filled(16, 1)));
      for (var i = 0; i < f.size; i++) {
        expect(f.freqOf(i), equals(1));
        expect(f.sum(i), equals(i + 1));
      }
      _checkInvariants(f);
    });

    test(
      'O(n) build matches an add-based build for non-power-of-two sizes',
      () {
        for (final size in [1, 2, 3, 5, 7, 13, 17, 100, 257]) {
          final fast = Fenwick(32, size)..init();

          // Reference: build the same all-ones tree using add().
          final ref = Fenwick(32, size);
          for (var i = 0; i < size; i++) {
            ref.add(i, 1);
          }

          expect(
            _freqList(fast),
            equals(_freqList(ref)),
            reason: 'freqOf mismatch for size $size',
          );
          for (var i = 0; i < size; i++) {
            expect(
              fast.sum(i),
              equals(ref.sum(i)),
              reason: 'sum($i) mismatch for size $size',
            );
          }
        }
      },
    );

    test('fully overwrites stale state (valid without a preceding reset)', () {
      final f = Fenwick(32, 8)..init();

      // Dirty the tree with skewed updates.
      for (var i = 0; i < 50; i++) {
        f.update(3);
        f.update(5);
      }
      expect(f.freqOf(3), greaterThan(1));

      // init() alone must restore the pristine all-ones state.
      f.init();
      expect(_freqList(f), equals(List.filled(8, 1)));
      expect(f.total, equals(8));
      _checkInvariants(f);
    });
  });

  group('Fenwick.freqOf', () {
    test('tracks single updates and stays consistent with sum', () {
      final f = Fenwick(32, 10)..init();

      f.update(4);
      f.update(4);
      f.update(7);

      expect(f.freqOf(4), equals(3));
      expect(f.freqOf(7), equals(2));
      expect(f.freqOf(0), equals(1));

      // sum reflects the same frequencies maintained directly.
      expect(f.range(4, 4), equals(f.freqOf(4)));
      _checkInvariants(f);
    });
  });

  group('Fenwick.findWithLow', () {
    test('low equals sum(symbol - 1) and bounds the value', () {
      final f = Fenwick(32, 12)..init();
      for (var i = 0; i < 12; i++) {
        for (var k = 0; k < i; k++) {
          f.update(i); // skew frequencies so symbols differ in size
        }
      }
      _checkInvariants(f);
    });

    test('first and last cumulative values resolve correctly', () {
      final f = Fenwick(32, 6)..init();

      final (firstSym, firstLow) = f.findWithLow(0);
      expect(firstSym, equals(0));
      expect(firstLow, equals(0));

      final (lastSym, lastLow) = f.findWithLow(f.total - 1);
      expect(lastSym, equals(f.size - 1));
      expect(lastLow, equals(f.sum(f.size - 2)));
    });
  });

  group('Fenwick.rescale', () {
    test('halves frequencies, keeps them >= 1, and stays consistent', () {
      // Small precision => small maxTotal => rescale triggers quickly.
      final f = Fenwick(8, 4)..init();
      expect(f.maxTotal, equals(15));

      // Hammer a single symbol to force at least one rescale.
      for (var i = 0; i < 200; i++) {
        f.update(2);
      }

      expect(f.total, lessThan(f.maxTotal));
      for (var i = 0; i < f.size; i++) {
        expect(f.freqOf(i), greaterThanOrEqualTo(1));
      }
      _checkInvariants(f);
    });

    test('keeps freqOf and the tree in sync through many rescales', () {
      final f = Fenwick(8, 8)..init();
      final rnd = Random(7);

      for (var i = 0; i < 5000; i++) {
        f.update(rnd.nextInt(f.size));
      }

      _checkInvariants(f);
    });
  });

  group('Fenwick.rebuild', () {
    test('sets both the tree and the direct-frequency array', () {
      final f = Fenwick(32, 5)..init();
      f.rebuild([2, 0, 5, 1, 3]);

      expect(_freqList(f), equals([2, 0, 5, 1, 3]));
      expect(f.total, equals(11));
      expect(f.sum(2), equals(7)); // 2 + 0 + 5
      expect(f.toFrequencyList(), equals([2, 0, 5, 1, 3]));
      _checkInvariants(f);
    });
  });

  group('Fenwick.reset', () {
    test('zeroes the tree, the frequencies and the total', () {
      final f = Fenwick(32, 6)..init();
      f.update(2);
      f.update(4);

      f.reset();

      expect(f.total, equals(0));
      expect(_freqList(f), equals(List.filled(6, 0)));
      for (var i = 0; i < f.size; i++) {
        expect(f.sum(i), equals(0));
      }
    });

    test('reset followed by init restores the pristine state', () {
      final f = Fenwick(32, 6)..init();
      f.update(1);
      f.reset();
      f.init();

      expect(_freqList(f), equals(List.filled(6, 1)));
      _checkInvariants(f);
    });
  });

  group('Fenwick storage', () {
    test('selects a wider typed list as precision grows', () {
      // maxTotal grows with precision; the tree must hold values without
      // truncation. A high-frequency symbol near maxTotal exercises this.
      final f = Fenwick(32, 4)..init();
      for (var i = 0; i < 1000; i++) {
        f.update(1);
      }
      expect(f.freqOf(1), greaterThan(255)); // would overflow a Uint8 store
      _checkInvariants(f);
    });
  });
}
