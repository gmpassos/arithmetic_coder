/// A bit-level writer that accumulates bits into bytes (MSB-first).
///
/// Designed for entropy encoders such as arithmetic coding, including
/// support for deferred (pending) bits used in renormalization.
class BitWriter {
  final _bytes = <int>[];

  /// Returns the written bytes.
  List<int> get bytes => _bytes;

  int _current = 0;
  int _count = 0;

  int _pendingBits = 0;

  /// Writes a single bit (0 or 1).
  ///
  /// Also flushes any pending opposite bits.
  void writeBit(int bit) {
    _writeRaw(bit);

    // flush pending opposite bits
    final flip = bit ^ 1;
    for (; _pendingBits > 0; _pendingBits--) {
      _writeRaw(flip);
    }
  }

  /// Defers a bit to be written later (used in arithmetic coding underflow handling).
  void writePending() {
    _pendingBits++;
  }

  void _writeRaw(int bit) {
    _current = (_current << 1) | bit;
    if (++_count == 8) {
      _bytes.add(_current);
      _current = 0;
      _count = 0;
    }
  }

  /// Finalizes the stream using [low] and [quarter] (arithmetic coding termination).
  void flushFinal(int low, int quarter) {
    _pendingBits++;
    if (low < quarter) {
      writeBit(0);
    } else {
      writeBit(1);
    }

    flush();
  }

  /// Flushes remaining bits, padding the last byte if necessary.
  void flush() {
    if (_count > 0) {
      _current <<= (8 - _count);
      _bytes.add(_current);
    }
  }
}
