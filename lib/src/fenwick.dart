/// A Fenwick Tree (Binary Indexed Tree) for frequency management and cumulative sums,
/// typically used in arithmetic coding for efficient symbol frequency updates.
class Fenwick {
  /// Number of bits of precision used to compute [maxTotal].
  final int precision;

  final List<int> _tree;

  /// Number of symbols managed by this Fenwick tree.
  final int size;

  /// Index of the last symbol (size - 1).
  final int eof;

  /// Maximum allowed total frequency before rescaling.
  final int maxTotal;

  /// Creates a Fenwick tree with [size] symbols and [precision] for [maxTotal] calculation.
  Fenwick(this.precision, this.size)
    : _tree = List.filled(size + 1, 0),
      eof = size - 1,
      maxTotal = computeMaxTotal(precision);

  /// Computes the maximum total frequency allowed for a given [precision].
  static int computeMaxTotal(int precision) {
    var maxTotal = 1 << (precision ~/ 2);
    return maxTotal;
  }

  int _total = 0;

  /// Current total of all frequencies.
  int get total => _total;

  /// Initializes all symbol frequencies to 1 and returns the total.
  int init() {
    _total = 0;
    for (var i = 0; i < size; ++i) {
      add(i, 1);
    }
    return _total;
  }

  /// Resets the tree and [total] to zero.
  void reset() {
    _total = 0;
    for (var i = 0; i < _tree.length; ++i) {
      _tree[i] = 0;
    }
  }

  /// Adds [delta] to the frequency of symbol [i] and updates [total].
  void add(int i, int delta) {
    for (i++; i <= size; i += i & -i) {
      _tree[i] += delta;
    }
    _total += delta;
  }

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

  /// Returns the current frequency of each symbol as a list.
  List<int> toFrequencyList() =>
      List<int>.generate(size, (i) => range(i, i)); // frequency per symbol

  /// Rebuilds the tree from a list of symbol frequencies [freq].
  void rebuild(List<int> freq) {
    _total = 0;

    // Copy frequencies directly (1-based tree)
    for (int i = 1; i <= size; i++) {
      _tree[i] = freq[i - 1];
      _total += _tree[i];
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
    final freq = List<int>.filled(size, 0);

    for (int i = 0; i < size; i++) {
      final f = range(i, i); // still O(log n), but done once
      freq[i] = f > 1 ? (f >> 1) : 1;
    }

    rebuild(freq);
  }
}
