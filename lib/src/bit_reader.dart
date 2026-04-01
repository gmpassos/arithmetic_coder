import 'dart:typed_data';

/// A bit-level reader that consumes a byte array and provides MSB-first access.
///
/// Commonly used in entropy decoding (e.g., arithmetic coding) where
/// fine-grained bit control is required.
class BitReader {
  final Uint8List _input;

  int _bytePos = 0;
  int _bitBuffer = 0;
  int _bitCount = 0;

  /// Creates a [BitReader] over the given byte [input].
  BitReader(this._input);

  /// Reads a single bit (most significant bit first).
  ///
  /// Returns `0` or `1`. If input is exhausted, returns `0`.
  int readBit() {
    if (_bitCount == 0) {
      _bitBuffer = _bytePos < _input.length ? _input[_bytePos++] : 0;
      _bitCount = 8;
    }

    final bit = (_bitBuffer >> 7) & 1;
    _bitBuffer <<= 1;
    _bitCount--;

    return bit;
  }

  /// Reads [n] bits and returns them packed into an integer.
  ///
  /// Bits are read MSB-first.
  int readBits(int n) {
    int value = 0;
    for (int i = 0; i < n; i++) {
      value = (value << 1) | readBit();
    }
    return value;
  }

  /// Reads the initial code value using [precision] bits.
  ///
  /// Typically used to initialize the decoder state in arithmetic coding.
  int readInitialCode(int precision) {
    int code = 0;
    for (int i = 0; i < precision; i++) {
      code = (code << 1) | readBit();
    }
    return code;
  }
}
