import 'package:arithmetic_coder/src/context_model.dart';
import 'package:test/test.dart';

const _precision = 32;
const _size = 257; // 256 byte values + EOF
const _eof = _size - 1;

void main() {
  group('ContextModel factory', () {
    test('creates the model matching the requested order', () {
      expect(ContextModel<ContextState>(0, _precision, _size).order, equals(0));
      expect(ContextModel<ContextState>(1, _precision, _size).order, equals(1));
      expect(ContextModel<ContextState>(2, _precision, _size).order, equals(2));
      expect(ContextModel<ContextState>(3, _precision, _size).order, equals(3));
    });

    test('throws on unsupported order', () {
      expect(
        () => ContextModel<ContextState>(4, _precision, _size),
        throwsUnsupportedError,
      );
    });

    test('maxContextOrder is 3', () {
      expect(ContextModel.maxContextOrder, equals(3));
    });
  });

  group('eof and totalSize', () {
    test('eof is size - 1 for every order', () {
      expect(ContextModelOrder0(_precision, _size).eof, equals(_eof));
      expect(ContextModelOrder1(_precision, _size).eof, equals(_eof));
      expect(ContextModelOrder2(_precision, _size).eof, equals(_eof));
      expect(ContextModelOrder3(_precision, _size).eof, equals(_eof));
    });

    test('totalSize reflects the full (possible) context capacity', () {
      expect(ContextModelOrder0(_precision, _size).totalSize, equals(_size));
      expect(
        ContextModelOrder1(_precision, _size).totalSize,
        equals(_size * _size),
      );
      expect(
        ContextModelOrder2(_precision, _size).totalSize,
        equals(_size * _size * _size),
      );

      final m3 = ContextModelOrder3(_precision, _size);
      final buckets = (_size ~/ m3.order3ShrinkFactor) + 1;
      expect(m3.totalSize, equals(buckets * _size * _size * _size));
    });
  });

  group('initialContext', () {
    test('starts every previous symbol at eof', () {
      expect(
        ContextModelOrder1(_precision, _size).initialContext().prev1,
        equals(_eof),
      );

      final c2 = ContextModelOrder2(_precision, _size).initialContext();
      expect([c2.prev2, c2.prev1], equals([_eof, _eof]));

      final c3 = ContextModelOrder3(_precision, _size).initialContext();
      expect([c3.prev3, c3.prev2, c3.prev1], equals([_eof, _eof, _eof]));
    });
  });

  group('updateContext shifts history', () {
    test('order-1 keeps the last symbol', () {
      final m = ContextModelOrder1(_precision, _size);
      final c = m.initialContext();

      m.updateContext(c, 42);
      expect(c.prev1, equals(42));
      m.updateContext(c, 7);
      expect(c.prev1, equals(7));
    });

    test('order-2 shifts prev1 -> prev2', () {
      final m = ContextModelOrder2(_precision, _size);
      final c = m.initialContext();

      m.updateContext(c, 10);
      expect([c.prev2, c.prev1], equals([_eof, 10]));
      m.updateContext(c, 20);
      expect([c.prev2, c.prev1], equals([10, 20]));
      m.updateContext(c, 30);
      expect([c.prev2, c.prev1], equals([20, 30]));
    });

    test('order-3 shifts prev2 -> prev3 and prev1 -> prev2', () {
      final m = ContextModelOrder3(_precision, _size);
      final c = m.initialContext();

      m.updateContext(c, 1);
      m.updateContext(c, 2);
      m.updateContext(c, 3);
      expect([c.prev3, c.prev2, c.prev1], equals([1, 2, 3]));
      m.updateContext(c, 4);
      expect([c.prev3, c.prev2, c.prev1], equals([2, 3, 4]));
    });
  });

  group('lazy model() allocation', () {
    test('returns a pristine all-ones tree on first access', () {
      final m = ContextModelOrder1(_precision, _size);
      final tree = m.model(ContextStateOrder1(5));

      expect(tree.total, equals(_size));
      expect(tree.toFrequencyList(), equals(List.filled(_size, 1)));
    });

    test('returns the same tree for the same context', () {
      final m = ContextModelOrder1(_precision, _size);

      final a = m.model(ContextStateOrder1(5));
      final b = m.model(ContextStateOrder1(5));
      expect(identical(a, b), isTrue);

      final c = m.model(ContextStateOrder1(6));
      expect(identical(a, c), isFalse);
    });

    test('order-2 distinguishes (prev2, prev1) order', () {
      final m = ContextModelOrder2(_precision, _size);

      final ab = m.model(ContextStateOrder2(1, 2));
      final ba = m.model(ContextStateOrder2(2, 1));
      expect(identical(ab, ba), isFalse);

      final ab2 = m.model(ContextStateOrder2(1, 2));
      expect(identical(ab, ab2), isTrue);
    });

    test('order-3 buckets prev3 by the shrink factor', () {
      final m = ContextModelOrder3(_precision, _size);
      final f = m.order3ShrinkFactor;

      final t0 = m.model(ContextStateOrder3(0, 5, 6));
      final tSameBucket = m.model(ContextStateOrder3(f - 1, 5, 6));
      final tNextBucket = m.model(ContextStateOrder3(f, 5, 6));

      expect(
        identical(t0, tSameBucket),
        isTrue,
        reason: 'prev3 within the same bucket shares a tree',
      );
      expect(
        identical(t0, tNextBucket),
        isFalse,
        reason: 'prev3 in a different bucket uses a different tree',
      );
    });
  });

  group('reset/init recycle and reuse trees', () {
    test('reset clears accumulated statistics for a reused context', () {
      final m = ContextModelOrder1(_precision, _size);

      final tree = m.model(ContextStateOrder1(5));
      tree.update(5);
      tree.update(5);
      expect(tree.freqOf(5), greaterThan(1));

      m.reset();

      final reused = m.model(ContextStateOrder1(5));
      // The pooled tree is recycled (same instance) and re-initialized clean.
      expect(identical(reused, tree), isTrue);
      expect(reused.toFrequencyList(), equals(List.filled(_size, 1)));
      expect(reused.total, equals(_size));
    });

    test('init behaves like reset for recycling', () {
      final m = ContextModelOrder2(_precision, _size);

      final tree = m.model(ContextStateOrder2(1, 2));
      tree.update(0);
      tree.update(0);

      m.init();

      final reused = m.model(ContextStateOrder2(1, 2));
      expect(reused.toFrequencyList(), equals(List.filled(_size, 1)));
    });

    test('a recycled tree can be re-bound to a different context', () {
      final m = ContextModelOrder1(_precision, _size);

      final first = m.model(ContextStateOrder1(5))..update(5);
      m.reset();

      // Only one tree was ever allocated, so the pool hands it back for a
      // brand new context, freshly initialized.
      final second = m.model(ContextStateOrder1(99));
      expect(identical(first, second), isTrue);
      expect(second.toFrequencyList(), equals(List.filled(_size, 1)));
    });
  });
}
