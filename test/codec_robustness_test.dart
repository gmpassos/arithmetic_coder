import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:arithmetic_coder/arithmetic_coder.dart';
import 'package:arithmetic_coder/src/context_model.dart';
import 'package:test/test.dart';

/// Robustness / fuzz suite: deliberately tries to break or crash the codec.
///
/// Two angles of attack:
///
/// 1. **Round-trip fuzzing** — throws a wide variety of inputs (every byte
///    value, boundary lengths, structured patterns, large random buffers that
///    force frequency rescaling, repeated reuse of one coder) at
///    `encode`/`decode` and requires a lossless round-trip every time.
///
/// 2. **Malformed-input hardening** — feeds bytes that were *never* produced by
///    `encode` (empty, all-zero, all-one, random garbage, truncated and
///    bit-flipped streams) straight into `decode`. A decoder must not hang or
///    take the whole process down: it must terminate, either returning some
///    bytes or throwing a catchable error.
///
/// Because `decode` is a single synchronous loop, an infinite loop in it cannot
/// be interrupted by a normal test `Timeout` (the event loop never runs). Each
/// malformed-input decode is therefore executed in a disposable isolate that is
/// killed if it overruns, so a runaway decode fails its test instead of
/// freezing the entire runner.
void main() {
  _roundTripFuzz();
  _malformedInputHardening();
}

// ---------------------------------------------------------------------------
// Part 1 — round-trip fuzzing (must always reproduce the input exactly).
// ---------------------------------------------------------------------------

void _roundTripFuzz() {
  for (var order = 0; order <= ContextModel.maxContextOrder; ++order) {
    group('round-trip fuzz (order: $order)', () {
      ArithmeticCoder coder() => ArithmeticCoder(order: order);

      void roundTrip(Uint8List input, {String? reason}) {
        final ac = coder();
        final decoded = ac.decode(ac.encode(input));
        expect(decoded, equals(input), reason: reason);
      }

      test('every single byte value 0..255 round-trips', () {
        for (var b = 0; b < 256; ++b) {
          roundTrip(Uint8List.fromList([b]), reason: 'byte $b');
        }
      });

      test('a run of each byte value round-trips', () {
        for (var b = 0; b < 256; ++b) {
          roundTrip(
            Uint8List.fromList(List.filled(40, b)),
            reason: 'run of $b',
          );
        }
      });

      test('all boundary lengths 0..64 of pseudo-random data round-trip', () {
        final rnd = Random(0xC0DE + order);
        for (var n = 0; n <= 64; ++n) {
          final input = Uint8List.fromList(
            List.generate(n, (_) => rnd.nextInt(256)),
          );
          roundTrip(input, reason: 'length $n');
        }
      });

      test('assorted random buffer sizes round-trip', () {
        final rnd = Random(987654 + order);
        for (final n in [1, 2, 3, 255, 256, 257, 1023, 1024, 1025, 8191]) {
          final input = Uint8List.fromList(
            List.generate(n, (_) => rnd.nextInt(256)),
          );
          roundTrip(input, reason: 'size $n');
        }
      });

      test('structured patterns round-trip', () {
        final patterns = <String, Uint8List>{
          'alternating 0/255': Uint8List.fromList(
            List.generate(2000, (i) => i.isEven ? 0 : 255),
          ),
          'sawtooth': Uint8List.fromList(List.generate(2000, (i) => i % 256)),
          'reverse sawtooth': Uint8List.fromList(
            List.generate(2000, (i) => 255 - (i % 256)),
          ),
          'sparse spikes': Uint8List.fromList(
            List.generate(2000, (i) => i % 97 == 0 ? 255 : 0),
          ),
          'two-symbol bias': Uint8List.fromList(
            List.generate(5000, (i) => i % 13 == 0 ? 7 : 3),
          ),
        };
        patterns.forEach((name, input) => roundTrip(input, reason: name));
      });

      test('large uniform-random buffer round-trips (stresses rescaling)', () {
        // ~100k symbols spread over every context drives many Fenwick trees
        // past maxTotal, exercising rescale + direct-frequency resync.
        final rnd = Random(424242 + order);
        final input = Uint8List.fromList(
          List.generate(100000, (_) => rnd.nextInt(256)),
        );
        roundTrip(input, reason: '100k uniform random');
      });

      test('single coder instance handles many inputs back-to-back', () {
        // Stresses the recycle/pool path in the lazy context models.
        final ac = coder();
        final rnd = Random(31337 + order);
        for (var iter = 0; iter < 40; ++iter) {
          final n = rnd.nextInt(2000);
          final input = Uint8List.fromList(
            List.generate(n, (_) => rnd.nextInt(256)),
          );
          final decoded = ac.decode(ac.encode(input));
          expect(decoded, equals(input), reason: 'iteration $iter (len $n)');
        }
      });

      test(
        'trailing garbage after a valid stream is ignored (stops at EOF)',
        () {
          // The decoder must stop at the embedded EOF symbol and not be derailed
          // by extra bytes appended after a complete encoding.
          final ac = coder();
          final input = Uint8List.fromList(
            List.generate(500, (i) => (i * 17 + 5) % 256),
          );
          final encoded = ac.encode(input);

          final rnd = Random(5 + order);
          final padded = Uint8List.fromList([
            ...encoded,
            ...List.generate(64, (_) => rnd.nextInt(256)),
          ]);

          expect(ac.decode(padded), equals(input));
        },
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Part 2 — malformed-input hardening (decode must terminate, never hang).
// ---------------------------------------------------------------------------

void _malformedInputHardening() {
  for (var order = 0; order <= ContextModel.maxContextOrder; ++order) {
    group('malformed-input hardening (order: $order)', () {
      Future<void> mustTerminate(String label, Uint8List data) async {
        final outcome = await _decodeGuarded(order, data);
        expect(
          outcome.terminated,
          isTrue,
          reason: '$label: decode $label ${outcome.detail}',
        );
      }

      test('empty bitstream', () => mustTerminate('empty', Uint8List(0)));

      test(
        'single zero byte',
        () => mustTerminate('single 0x00', Uint8List.fromList([0])),
      );

      test(
        'all-zero bitstream',
        () => mustTerminate('all 0x00', Uint8List(256)),
      );

      test(
        'all-one bitstream',
        () => mustTerminate(
          'all 0xFF',
          Uint8List.fromList(List.filled(256, 0xFF)),
        ),
      );

      test('pseudo-random garbage', () {
        final rnd = Random(0xBAD + order);
        final data = Uint8List.fromList(
          List.generate(512, (_) => rnd.nextInt(256)),
        );
        return mustTerminate('random garbage', data);
      });

      test('truncated valid stream', () async {
        final input = Uint8List.fromList(
          List.generate(300, (i) => (i * 11) % 256),
        );
        final encoded = ArithmeticCoder(order: order).encode(input);
        for (final keep in [encoded.length ~/ 2, 4, 1]) {
          if (keep > encoded.length) continue;
          await mustTerminate(
            'truncated to $keep/${encoded.length}',
            Uint8List.sublistView(encoded, 0, keep),
          );
        }
      });

      test('bit-flipped valid stream', () async {
        final input = Uint8List.fromList(
          List.generate(300, (i) => (i * 11) % 256),
        );
        final encoded = ArithmeticCoder(order: order).encode(input);
        final rnd = Random(77 + order);
        for (var trial = 0; trial < 5; ++trial) {
          final corrupt = Uint8List.fromList(encoded);
          // Flip a handful of random bits.
          for (var f = 0; f < 8; ++f) {
            final idx = rnd.nextInt(corrupt.length);
            corrupt[idx] ^= 1 << rnd.nextInt(8);
          }
          await mustTerminate('bit-flip trial $trial', corrupt);
        }
      });
    });
  }
}

/// Outcome of a guarded decode attempt.
class _DecodeOutcome {
  /// Whether decode returned (or threw) before the timeout. `false` means it
  /// overran the deadline — almost certainly an infinite loop.
  final bool terminated;

  /// Human-readable detail for failure messages.
  final String detail;

  _DecodeOutcome(this.terminated, this.detail);
}

/// Top-level isolate entry point: decodes [msg] = `[SendPort, order, data]` and
/// sends back `['ok', length]` or `['err', message]`. Run in its own isolate so
/// a non-terminating decode can be killed (a synchronous infinite loop cannot
/// be interrupted by a `Timeout` on the test).
void _decodeIsolate(List<Object?> msg) {
  final port = msg[0] as SendPort;
  final order = msg[1] as int;
  final data = msg[2] as Uint8List;
  try {
    final out = ArithmeticCoder(order: order).decode(data);
    port.send(['ok', out.length]);
  } catch (e) {
    port.send(['err', e.toString()]);
  }
}

/// Runs `decode(data)` for the given [order] in a disposable isolate, killing it
/// if it does not finish within [timeout]. Returns whether it terminated.
Future<_DecodeOutcome> _decodeGuarded(
  int order,
  Uint8List data, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(_decodeIsolate, <Object?>[
    rp.sendPort,
    order,
    data,
  ]);
  final completer = Completer<List>();
  final sub = rp.listen((m) {
    if (!completer.isCompleted) completer.complete(m as List);
  });

  List? msg;
  try {
    msg = await completer.future.timeout(timeout);
  } on TimeoutException {
    msg = null;
  } finally {
    iso.kill(priority: Isolate.immediate);
    await sub.cancel();
    rp.close();
  }

  if (msg == null) {
    return _DecodeOutcome(false, 'did not terminate within $timeout');
  }
  final kind = msg[0];
  return _DecodeOutcome(
    true,
    kind == 'err' ? 'threw: ${msg[1]}' : 'returned ${msg[1]} bytes',
  );
}
