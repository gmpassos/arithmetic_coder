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

  bool _exhausted = false;
  int _paddingBits = 0;

  /// Creates a [BitReader] over the given byte [input].
  BitReader(this._input);

  /// Number of bits returned after the input bytes were fully consumed.
  ///
  /// Once the underlying bytes run out [readBit] keeps returning `0` padding;
  /// this counts those synthetic bits. A decoder uses it to detect malformed or
  /// truncated streams that never contain an EOF symbol, instead of looping
  /// forever feeding on endless zero padding.
  int get paddingBits => _paddingBits;

  /// Reads a single bit (most significant bit first).
  ///
  /// Returns `0` or `1`. If input is exhausted, returns `0` and counts the bit
  /// towards [paddingBits].
  int readBit() {
    if (_bitCount == 0) {
      if (_bytePos < _input.length) {
        _bitBuffer = _input[_bytePos++];
      } else {
        _bitBuffer = 0;
        _exhausted = true;
      }
      _bitCount = 8;
    }

    final bit = (_bitBuffer >> 7) & 1;
    _bitBuffer <<= 1;
    _bitCount--;

    if (_exhausted) _paddingBits++;

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
