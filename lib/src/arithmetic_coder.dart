import 'dart:typed_data';

import 'bit_reader.dart';
import 'bit_writer.dart';
import 'context_model.dart';
import 'fenwick.dart';

/// An adaptive arithmetic coder for lossless compression.
///
/// Uses a [Fenwick] tree to maintain cumulative symbol frequencies,
/// enabling efficient probability updates and queries in logarithmic time.
///
/// Supports finite-order context models (Markov models), allowing the
/// probability of each symbol to depend on previously seen symbols:
///
/// - `order = 0` → no context (independent symbols)
/// - `order = 1` → depends on previous symbol
/// - `order = 2` → depends on previous two symbols
///
/// The model is adaptive: frequencies are updated after each symbol,
/// improving compression as more data is processed.
///
/// Internally, the coder:
/// - Maintains a range `[low, high]` with fixed integer precision
/// - Narrows the range based on cumulative frequencies
/// - Emits bits incrementally as the range stabilizes
/// - Performs rescaling to keep values within bounds
///
/// An explicit EOF symbol is required to terminate decoding.
class ArithmeticCoder {
  static const int _precision = 32;
  static const int _maxRange = (1 << _precision) - 1;

  static const int _half = 1 << (_precision - 1);
  static const int _quarter = _half >> 1;
  static const int _threeQuarter = _quarter * 3;

  /// Order of the context model (0, 1, or 2).
  ///
  /// Determines how many previous symbols are used to predict
  /// the next one.
  final int order;

  ArithmeticCoder({this.order = 0});

  ContextModel? _models;

  /// Lazily creates and initializes the [ContextModel] used by the coder.
  ///
  /// The model is built on first use and then reused across operations.
  /// Calling this method ensures the model is reset to its initial state
  /// before encoding or decoding begins.
  ///
  /// The model size is fixed to `257` symbols:
  /// - `0..255` → byte values
  /// - `256` → EOF (end-of-stream marker)
  ///
  /// The selected model depends on the configured [order].
  ///
  /// See [ContextModel] and [Fenwick].
  ContextModel _buildModels() {
    var models = _models ??= ContextModel(order, _precision, 257);
    models.reset();
    return models;
  }

  /// Encodes [input] bytes into a compressed bitstream.
  ///
  /// Uses adaptive frequencies with a Fenwick tree and writes bits via [BitWriter].
  /// Appends an EOF symbol at the end of the stream.
  Uint8List encode(Uint8List input) {
    final models = _buildModels();
    models.init();

    int low = 0;
    int high = _maxRange;

    final bitWriter = BitWriter();
    final context = models.initialContext();

    void encodeSymbol(int symbol) {
      final model = models.model(context);

      final range = high - low + 1;

      final symLow = model.sum(symbol - 1);
      final symHigh = model.sum(symbol);

      final total = model.total;

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

      model.update(symbol);
      models.updateContext(context, symbol);
    }

    for (var i = 0; i < input.length; ++i) {
      final b = input[i];
      encodeSymbol(b);
    }

    encodeSymbol(models.eof); // EOF

    bitWriter.flushFinal(low, _quarter);

    return Uint8List.fromList(bitWriter.bytes);
  }

  /// Decodes a compressed [input] bitstream back into the original bytes.
  ///
  /// Uses the same adaptive model as [encode]. Stops when EOF symbol is reached.
  Uint8List decode(Uint8List input) {
    final models = _buildModels();
    models.init();

    int low = 0;
    int high = _maxRange;

    final bitReader = BitReader(input);
    final context = models.initialContext();

    var code = bitReader.readInitialCode(_precision);

    final output = <int>[];

    while (true) {
      final model = models.model(context);

      final range = high - low + 1;
      final value = ((code - low + 1) * model.total - 1) ~/ range;

      final symbol = model.findByCumulative(value);
      if (symbol == 256) break;

      output.add(symbol);

      final symLow = model.sum(symbol - 1);
      final symHigh = model.sum(symbol);

      final total = model.total;

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

      model.update(symbol);

      models.updateContext(context, symbol);
    }

    return Uint8List.fromList(output);
  }

  @override
  String toString() =>
      'ArithmeticCoder{order: $order, models.totalSize: ${_models?.totalSize}}';
}
