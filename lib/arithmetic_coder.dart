/// Adaptive arithmetic coding using a Fenwick tree (binary indexed tree).
///
/// This library provides efficient lossless compression and decompression
/// of byte streams using arithmetic coding with a dynamic frequency model.
///
/// Features:
/// - Adaptive model (no prior statistics required)
/// - Fenwick tree for fast cumulative frequency queries
/// - Bit-level I/O for compact output
/// - Built-in EOF symbol handling
///
/// Usage:
/// ```dart
/// import 'package:arithmetic_coder/arithmetic_coder.dart';
///
/// final input = Uint8List.fromList([1, 2, 3, 3, 2, 1]);
///
/// final compressed = ArithmeticCoder.encode(input);
/// final decompressed = ArithmeticCoder.decode(compressed);
///
/// assert(const ListEquality().equals(input, decompressed));
/// ```
///
/// Notes:
/// - The symbol alphabet is fixed to 256 byte values plus EOF (257 total).
/// - Frequencies are automatically rescaled to prevent overflow.
/// - Uses 32-bit arithmetic precision.
///
/// See also:
/// - [ArithmeticCoder]
library;

export 'src/arithmetic_coder.dart';
