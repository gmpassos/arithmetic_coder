import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:arithmetic_coder/arithmetic_coder.dart';

/// Benchmark for [ArithmeticCoder] encode/decode across context orders.
///
/// Run with:
/// ```
/// dart run benchmark/arithmetic_coder_benchmark.dart
/// ```
///
/// Reports, per dataset and order: compression ratio, encode/decode
/// throughput (MB/s) and per-call latency. Integrity is verified on every
/// run so a broken optimization shows up immediately.
///
/// Use this as a baseline to track future performance and ratio changes.
void main(List<String> args) {
  final orders = <int>[0, 1, 2, 3];

  final datasets = <_Dataset>[
    _Dataset('english-like text', _englishLike(64 * 1024)),
    _Dataset('repetitive text', _repetitive(64 * 1024)),
    _Dataset('random bytes', _random(64 * 1024)),
    _Dataset('skewed bytes', _skewed(64 * 1024)),
  ];

  print('arithmetic_coder benchmark');
  print('Dart: ${_dartVersion()}');
  print('');

  for (final ds in datasets) {
    print('Dataset: ${ds.name}  (${_fmtBytes(ds.bytes.length)})');
    print(
      '  ${'order'.padRight(6)}'
      '${'ratio'.padLeft(8)}'
      '${'enc MB/s'.padLeft(12)}'
      '${'dec MB/s'.padLeft(12)}'
      '${'enc ms'.padLeft(10)}'
      '${'dec ms'.padLeft(10)}',
    );

    for (final order in orders) {
      final r = _benchmarkOrder(order, ds.bytes);
      print(
        '  ${order.toString().padRight(6)}'
        '${r.ratio.toStringAsFixed(4).padLeft(8)}'
        '${r.encodeMbPerSec.toStringAsFixed(1).padLeft(12)}'
        '${r.decodeMbPerSec.toStringAsFixed(1).padLeft(12)}'
        '${r.encodeMs.toStringAsFixed(2).padLeft(10)}'
        '${r.decodeMs.toStringAsFixed(2).padLeft(10)}'
        '${r.ok ? '' : '   <-- INTEGRITY FAIL'}',
      );
    }
    print('');
  }
}

/// Benchmarks a single [order] over [input], returning aggregated metrics.
_Result _benchmarkOrder(int order, Uint8List input) {
  final ac = ArithmeticCoder(order: order);

  // Warm up (also lets the JIT optimize and the model pool fill).
  final warm = ac.encode(input);
  final ok = _listEquals(ac.decode(warm), input);
  final compressed = warm;

  // Auto-scale iterations so each phase runs long enough to be meaningful,
  // bounded so the whole benchmark stays quick.
  final iterations = _iterationsFor(input.length);

  final encodeMs = _timeMs(iterations, () => ac.encode(input));
  final decodeMs = _timeMs(iterations, () => ac.decode(compressed));

  final mb = input.length / (1024 * 1024);

  return _Result(
    ratio: compressed.length / input.length,
    encodeMs: encodeMs,
    decodeMs: decodeMs,
    encodeMbPerSec: encodeMs > 0 ? mb / (encodeMs / 1000) : double.infinity,
    decodeMbPerSec: decodeMs > 0 ? mb / (decodeMs / 1000) : double.infinity,
    ok: ok,
  );
}

/// Runs [action] [iterations] times and returns the average wall time in ms.
double _timeMs(int iterations, void Function() action) {
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; ++i) {
    action();
  }
  sw.stop();
  return sw.elapsedMicroseconds / 1000 / iterations;
}

int _iterationsFor(int length) {
  if (length <= 16 * 1024) return 50;
  if (length <= 128 * 1024) return 20;
  return 5;
}

// --- Datasets ---------------------------------------------------------------

Uint8List _englishLike(int length) {
  const sample =
      'the quick brown fox jumps over the lazy dog. '
      'pack my box with five dozen liquor jugs. '
      'how razorback jumping frogs can level six piqued gymnasts! ';
  final bytes = utf8.encode(sample);
  final out = Uint8List(length);
  for (var i = 0; i < length; ++i) {
    out[i] = bytes[i % bytes.length];
  }
  return out;
}

Uint8List _repetitive(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; ++i) {
    out[i] = 65 + (i % 4); // "ABCDABCD..."
  }
  return out;
}

Uint8List _random(int length) {
  final rnd = Random(12345);
  final out = Uint8List(length);
  for (var i = 0; i < length; ++i) {
    out[i] = rnd.nextInt(256);
  }
  return out;
}

/// Bytes drawn from a skewed distribution (a few common values dominate),
/// representative of real-world data where entropy coding pays off.
Uint8List _skewed(int length) {
  final rnd = Random(67890);
  final out = Uint8List(length);
  for (var i = 0; i < length; ++i) {
    // Square the uniform sample to bias toward low byte values.
    final r = rnd.nextDouble();
    out[i] = (r * r * 256).floor().clamp(0, 255);
  }
  return out;
}

// --- Support ----------------------------------------------------------------

class _Dataset {
  final String name;
  final Uint8List bytes;

  _Dataset(this.name, this.bytes);
}

class _Result {
  final double ratio;
  final double encodeMs;
  final double decodeMs;
  final double encodeMbPerSec;
  final double decodeMbPerSec;
  final bool ok;

  _Result({
    required this.ratio,
    required this.encodeMs,
    required this.decodeMs,
    required this.encodeMbPerSec,
    required this.decodeMbPerSec,
    required this.ok,
  });
}

String _fmtBytes(int n) {
  if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MiB';
  if (n >= 1024) return '${(n / 1024).toStringAsFixed(1)} KiB';
  return '$n B';
}

String _dartVersion() {
  // Platform.version is e.g. "3.10.9 (stable) ... on \"macos_x64\"".
  final v = Platform.version;
  final space = v.indexOf(' ');
  return space > 0 ? v.substring(0, space) : v;
}

bool _listEquals(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
