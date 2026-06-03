import 'dart:typed_data';

/// A Fenwick Tree (Binary Indexed Tree) for frequency management and cumulative sums,
/// typically used in arithmetic coding for efficient symbol frequency updates.
class Fenwick {
  /// Number of bits of precision used to compute [maxTotal].
  final int precision;

  /// Number of symbols managed by this Fenwick tree.
  final int size;

  /// Index of the last symbol (size - 1).
  final int eof;

  /// Maximum allowed total frequency before rescaling.
  final int maxTotal;

  late final List<int> _tree;

  /// Direct per-symbol frequencies (0-based), kept in sync with [_tree].
  ///
  /// Maintaining the raw frequencies alongside the cumulative tree turns
  /// single-symbol frequency lookups into O(1) array reads, avoiding extra
  /// O(log n) tree walks in the encode/decode hot path and letting [rescale]
  /// run in O(n) instead of O(n log n).
  late final List<int> _freq;

  /// Creates a Fenwick tree with [size] symbols and [precision] for [maxTotal] calculation.
  Fenwick(this.precision, this.size)
    : eof = size - 1,
      maxTotal = computeMaxTotal(precision) {
    _tree = _buildIntList(size + 1, maxTotal);
    _freq = _buildIntList(size, maxTotal);
  }

  static List<int> _buildIntList(int length, int maxValue) {
    final neededBits = maxValue.bitLength;

    if (neededBits <= 8) {
      return Uint8List(length);
    } else if (neededBits <= 16) {
      return Uint16List(length);
    } else if (neededBits <= 32) {
      return Uint32List(length);
    } else if (neededBits <= 64) {
      return Uint64List(length);
    } else {
      throw UnsupportedError(
        "Cannot create a typed list for values requiring more than 64 bits> maxValue: $maxValue ; neededBits: $neededBits",
      );
    }
  }

  /// Computes the maximum total frequency allowed for a given [precision].
  static int computeMaxTotal(int precision) {
    var maxTotal = (1 << (precision ~/ 2)) - 1;
    return maxTotal;
  }

  int _total = 0;

  /// Current total of all frequencies.
  int get total => _total;

  /// Initializes all symbol frequencies to 1 and returns the total.
  ///
  /// Builds the tree directly in O(n): when every frequency is 1 the Fenwick
  /// node at 1-based index `i` covers exactly `lowbit(i) == i & -i` elements,
  /// so the cumulative tree can be filled without any per-element walks. This
  /// also fully overwrites prior state, so [init] is valid on a recycled tree
  /// without a preceding [reset].
  int init() {
    _total = size;

    final freq = _freq;
    for (var i = 0; i < size; ++i) {
      freq[i] = 1;
    }

    final tree = _tree;
    for (var i = 1; i <= size; ++i) {
      tree[i] = i & -i;
    }

    return _total;
  }

  /// Resets the tree and [total] to zero.
  void reset() {
    _total = 0;
    for (var i = 0; i < _tree.length; ++i) {
      _tree[i] = 0;
    }
    for (var i = 0; i < _freq.length; ++i) {
      _freq[i] = 0;
    }
  }

  /// Adds [delta] to the frequency of symbol [i] and updates [total].
  void add(int i, int delta) {
    _freq[i] += delta;
    for (i++; i <= size; i += i & -i) {
      _tree[i] += delta;
    }
    _total += delta;
  }

  /// Returns the current frequency of [symbol] in O(1).
  int freqOf(int symbol) => _freq[symbol];

  /// Updates the frequency of [symbol] by 1 and rescales if [total] exceeds [maxTotal].
  void update(int symbol) {
    add(symbol, 1);

    if (_total >= maxTotal) {
      rescale();
    }
  }

  /// Returns the prefix sum of frequencies up to index [i].
  ///
  /// If [i] < 0 returns 0.
  int sum(int i) {
    int s = 0;
    for (i++; i > 0; i -= i & -i) {
      s += _tree[i];
    }
    return s;
  }

  /// Returns the sum of frequencies in the range [l, r].
  int range(int l, int r) => sum(r) - (l > 0 ? sum(l - 1) : 0);

  /// Finds the smallest index such that the prefix sum > [value].
  ///
  /// Returns 0-based index.
  int findByCumulative(int value) {
    int idx = 0;
    int bitMask = 1 << (size.bitLength - 1);

    for (; bitMask != 0; bitMask >>= 1) {
      final t = idx + bitMask;
      if (t <= size && _tree[t] <= value) {
        value -= _tree[t];
        idx = t;
      }
    }
    return idx; // already 0-based
  }

  /// Decodes the symbol containing cumulative frequency [value], returning both
  /// the 0-based `symbol` and its `low` (the cumulative frequency *below* it,
  /// i.e. `sum(symbol - 1)`).
  ///
  /// The `low` is produced for free as a by-product of the descent, saving an
  /// extra [sum] walk in the decoder. The matching upper bound is
  /// `low + freqOf(symbol)`.
  (int symbol, int low) findWithLow(int value) {
    int idx = 0;
    int low = 0;
    int bitMask = 1 << (size.bitLength - 1);

    for (; bitMask != 0; bitMask >>= 1) {
      final t = idx + bitMask;
      if (t <= size && _tree[t] <= value) {
        value -= _tree[t];
        low += _tree[t];
        idx = t;
      }
    }
    return (idx, low); // idx already 0-based; low == sum(idx - 1)
  }

  /// Returns the current frequency of each symbol as a list.
  List<int> toFrequencyList() => List<int>.of(_freq); // frequency per symbol

  /// Rebuilds the tree from a list of symbol frequencies [freq].
  void rebuild(List<int> freq) {
    _total = 0;

    // Copy frequencies directly (1-based tree) and into the direct-frequency
    // array (0-based), keeping both representations in sync.
    for (int i = 1; i <= size; i++) {
      final f = freq[i - 1];
      _tree[i] = f;
      _freq[i - 1] = f;
      _total += f;
    }

    // Build Fenwick in O(n)
    for (int i = 1; i <= size; i++) {
      int j = i + (i & -i);
      if (j <= size) {
        _tree[j] += _tree[i];
      }
    }
  }

  /// Rescales frequencies to avoid overflow.
  ///
  /// Each frequency is halved, but kept >= 1.
  /// This preserves symbol availability and keeps total bounded.
  void rescale() {
    final freq = _freq;

    // Halve in place using the O(1) direct frequencies, then rebuild the tree.
    for (int i = 0; i < size; i++) {
      final f = freq[i];
      freq[i] = f > 1 ? (f >> 1) : 1;
    }

    rebuild(freq);
  }
}
