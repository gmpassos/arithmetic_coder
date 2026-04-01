import 'dart:typed_data';

import 'bit_reader.dart';
import 'bit_writer.dart';
import 'fenwick.dart';

/// An adaptive arithmetic coder using a [Fenwick] tree for symbol frequencies.
///
/// Supports encoding and decoding of byte streams with dynamic probability
/// updates and rescaling to avoid overflow.
class ArithmeticCoder {
  static const int _precision = 32;
  static const int _maxRange = (1 << _precision) - 1;

  static const int _half = 1 << (_precision - 1);
  static const int _quarter = _half >> 1;
  static const int _threeQuarter = _quarter * 3;

  /// Encodes [input] bytes into a compressed bitstream.
  ///
  /// Uses adaptive frequencies with a Fenwick tree and writes bits via [BitWriter].
  /// Appends an EOF symbol at the end of the stream.
  Uint8List encode(Uint8List input) {
    final fenwick = Fenwick(_precision, 257);
    fenwick.init();

    int low = 0;
    int high = _maxRange;

    var bitWriter = BitWriter();

    void encodeSymbol(int symbol) {
      final range = high - low + 1;

      final symLow = fenwick.sum(symbol - 1);
      final symHigh = fenwick.sum(symbol);

      final total = fenwick.total;

      high = low + (range * symHigh ~/ total) - 1;
      low = low + (range * symLow ~/ total);

      while (true) {
        if (high < _half) {
          bitWriter.writeBit(0);
        } else if (low >= _half) {
          bitWriter.writeBit(1);
          low -= _half;
          high -= _half;
        } else if (low >= _quarter && high < _threeQuarter) {
          bitWriter.writePending();
          low -= _quarter;
          high -= _quarter;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
      }

      fenwick.update(symbol);
    }

    for (final b in input) {
      encodeSymbol(b);
    }

    encodeSymbol(fenwick.eof); // EOF

    bitWriter.flushFinal(low, _quarter);

    return Uint8List.fromList(bitWriter.bytes);
  }

  /// Decodes a compressed [input] bitstream back into the original bytes.
  ///
  /// Uses the same adaptive model as [encode]. Stops when EOF symbol is reached.
  Uint8List decode(Uint8List input) {
    final fenwick = Fenwick(_precision, 257);
    fenwick.init();

    int low = 0;
    int high = _maxRange;

    final bitReader = BitReader(input);

    var code = bitReader.readInitialCode(_precision);

    final output = <int>[];

    while (true) {
      final range = high - low + 1;
      final value = ((code - low + 1) * fenwick.total - 1) ~/ range;

      final symbol = fenwick.findByCumulative(value);
      if (symbol == 256) break;

      output.add(symbol);

      final symLow = fenwick.sum(symbol - 1);
      final symHigh = fenwick.sum(symbol);

      final total = fenwick.total;

      high = low + (range * symHigh ~/ total) - 1;
      low = low + (range * symLow ~/ total);

      while (true) {
        if (high < _half) {
          // nothing
        } else if (low >= _half) {
          code -= _half;
          low -= _half;
          high -= _half;
        } else if (low >= _quarter && high < _threeQuarter) {
          code -= _quarter;
          low -= _quarter;
          high -= _quarter;
        } else {
          break;
        }

        low <<= 1;
        high = (high << 1) | 1;
        code = (code << 1) | bitReader.readBit();
      }

      fenwick.update(symbol);
    }

    return Uint8List.fromList(output);
  }
}
