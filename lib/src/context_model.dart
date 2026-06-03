import 'fenwick.dart';

/// Represents the state (context) used by a [ContextModel].
///
/// A context captures the previously seen symbols that influence
/// the probability distribution of the next symbol.
///
/// The exact contents depend on the model order:
/// - Order-0 → no state
/// - Order-1 → previous symbol
/// - Order-2 → previous two symbols
abstract class ContextState {
  const ContextState();

  /// The order of this context state.
  ///
  /// Determines how many previous symbols are used to predict the next symbol:
  /// - `0` → no context (symbols independent)
  /// - `1` → depends on the previous symbol
  /// - `2` → depends on the previous two symbols
  /// - `3` → depends on the previous three symbols
  int get order;
}

/// A context-based adaptive probability model used by arithmetic coding.
///
/// This model implements a **finite-order Markov model**, where the
/// probability of the next symbol depends only on a limited number
/// of previously seen symbols (the context).
///
/// Instances are created via the factory constructor based on the
/// desired order:
///
/// - `order = 0` → no context (independent symbols)
/// - `order = 1` → depends on previous symbol
/// - `order = 2` → depends on previous two symbols
///
/// Internally, each context maps to a [Fenwick] tree storing symbol
/// frequencies, allowing efficient cumulative frequency queries
/// required by arithmetic coding.
///
/// The model is **adaptive**:
/// - Frequencies are updated after each symbol
/// - Probability estimates improve over time
///
/// ### Lifecycle
///
/// - [init] → initializes frequency tables
/// - [reset] → clears and reinitializes state
/// - [initialContext] → returns the starting context
/// - [updateContext] → updates context after each symbol
/// - [model] → returns the frequency model for a given context
abstract class ContextModel<C extends ContextState> {
  /// The maximum order of the context model supported by this class.
  ///
  /// - `0` → no context (symbols independent)
  /// - `1` → depends on previous symbol
  /// - `2` → depends on previous two symbols
  /// - `3` → depends on previous three symbols
  static const maxContextOrder = 3;

  ContextModel._();

  /// Creates a [ContextModel] for the given [order].
  ///
  /// - [precision] controls internal frequency scaling
  /// - [size] is the number of symbols (including EOF)
  ///
  /// Throws [UnsupportedError] if the order is not supported.
  factory ContextModel(int order, int precision, int size) {
    switch (order) {
      case 0:
        return ContextModelOrder0(precision, size) as ContextModel<C>;
      case 1:
        return ContextModelOrder1(precision, size) as ContextModel<C>;
      case 2:
        return ContextModelOrder2(precision, size) as ContextModel<C>;
      case 3:
        return ContextModelOrder3(precision, size) as ContextModel<C>;

      default:
        throw UnsupportedError("Unsupported order: $order");
    }
  }

  /// The order of this context model.
  ///
  /// Determines how many previous symbols are used to predict the next symbol:
  /// - `0` → no context (symbols independent)
  /// - `1` → depends on the previous symbol
  /// - `2` → depends on the previous two symbols
  /// - `3` → depends on the previous three symbols
  int get order;

  /// The EOF (end-of-stream) symbol.
  ///
  /// This symbol must be encoded to signal the end of the input.
  int get eof;

  /// Total number of symbols managed by the model.
  ///
  /// Includes all possible symbols plus the EOF symbol.
  int get totalSize;

  /// Initializes the model's internal frequency tables.
  ///
  /// Typically assigns non-zero initial frequencies to all symbols.
  void init();

  /// Resets the model to its initial state.
  ///
  /// Clears all accumulated statistics and reinitializes frequencies.
  void reset();

  /// Returns the initial context used before any symbols are processed.
  C initialContext();

  /// Updates the context after processing a [symbol].
  ///
  /// This shifts or modifies the context to reflect recent history.
  void updateContext(C prevContext, int symbol);

  /// Returns the [Fenwick] tree representing the symbol distribution
  /// for the given [context].
  ///
  /// The returned structure provides cumulative frequencies required
  /// by the arithmetic coder.
  Fenwick model(C context);
}

/// Context state for an order-0 model (no history).
class ContextStateOrder0 extends ContextState {
  const ContextStateOrder0();

  @override
  int get order => 0;
}

/// Order-0 context model (no dependency on previous symbols).
///
/// All symbols share a single frequency distribution.
///
/// See [ContextModel].
class ContextModelOrder0 extends ContextModel<ContextStateOrder0> {
  late final Fenwick _model;

  final int precision;
  final int size;

  @override
  final int eof;

  ContextModelOrder0(this.precision, this.size)
    : _model = Fenwick(precision, size),
      eof = size - 1,
      super._() {
    assert(eof == _model.eof);
  }

  @override
  int get order => 0;

  @override
  int get totalSize => _model.size;

  @override
  void init() => _model.init();

  @override
  reset() => _model.reset();

  final _context = const ContextStateOrder0();

  @override
  ContextStateOrder0 initialContext() => _context;

  @override
  void updateContext(ContextStateOrder0 prevContext, int symbol) {}

  @override
  Fenwick model(ContextStateOrder0 context) => _model;
}

/// Base class for context models that keep one [Fenwick] frequency tree per
/// context, allocating each tree lazily on first use.
///
/// Higher orders have an enormous number of *possible* contexts (order-1 has
/// `size`, order-2 `size²`, order-3 even more), yet any given input only ever
/// visits a small fraction of them. Eagerly creating and [init]ializing a tree
/// for every context therefore wastes both memory and time, dominated by the
/// per-call cost of [init]/[reset] over millions of unused trees.
///
/// Instead, trees are created the first time their context is requested via
/// [model] and are recycled through an internal pool across encode/decode
/// runs. The output is identical to the eager model: each context still sees a
/// freshly [Fenwick.init]ialized tree the first time it is used.
abstract class _LazyContextModel<C extends ContextState>
    extends ContextModel<C> {
  /// Number of bits of precision passed to each [Fenwick] tree.
  final int precision;

  /// Number of symbols (alphabet size including EOF) per [Fenwick] tree.
  final int size;

  @override
  final int eof;

  /// One slot per context; `null` until the context is first used.
  final List<Fenwick?> _slots;

  /// Indices into [_slots] that currently hold a live tree.
  final List<int> _active = [];

  /// Recycled (zeroed) trees available for reuse, avoiding re-allocation.
  final List<Fenwick> _pool = [];

  _LazyContextModel(this.precision, this.size, int contexts)
    : eof = size - 1,
      _slots = List<Fenwick?>.filled(contexts, null),
      super._();

  /// Maps a [context] to its slot index in [_slots].
  int contextIndex(C context);

  @override
  int get totalSize => _slots.length * size;

  @override
  void init() => _recycle();

  @override
  void reset() => _recycle();

  /// Returns all live trees to the pool and clears their slots.
  ///
  /// Cost is proportional to the number of contexts actually used, not the
  /// total number of possible contexts. Trees are not cleared here: every
  /// tree taken from the pool is re-[Fenwick.init]ialized on acquisition,
  /// which fully overwrites any stale state.
  void _recycle() {
    final active = _active;
    if (active.isEmpty) return;

    final slots = _slots;
    final pool = _pool;
    for (var i = 0; i < active.length; ++i) {
      final idx = active[i];
      pool.add(slots[idx]!);
      slots[idx] = null;
    }
    active.clear();
  }

  @override
  Fenwick model(C context) {
    final idx = contextIndex(context);
    final slots = _slots;

    var tree = slots[idx];
    if (tree == null) {
      final pool = _pool;
      tree = pool.isNotEmpty
          ? (pool.removeLast()..init())
          : (Fenwick(precision, size)..init());
      slots[idx] = tree;
      _active.add(idx);
    }
    return tree;
  }
}

/// Context state for an order-1 model (depends on previous symbol).
///
/// Stores the last symbol (`symbol`) and the one before it (`prev1`).
class ContextStateOrder1 extends ContextState {
  int prev1;

  ContextStateOrder1(this.prev1);

  @override
  int get order => 1;

  void update(int symbol) {
    prev1 = symbol;
  }
}

/// Order-1 context model (depends on the previous symbol).
///
/// Maintains one lazily-allocated frequency distribution per previous symbol.
class ContextModelOrder1 extends _LazyContextModel<ContextStateOrder1> {
  ContextModelOrder1(int precision, int size) : super(precision, size, size);

  @override
  int get order => 1;

  @override
  ContextStateOrder1 initialContext() => ContextStateOrder1(eof);

  @override
  void updateContext(ContextStateOrder1 prevContext, int symbol) {
    prevContext.update(symbol);
  }

  @override
  int contextIndex(ContextStateOrder1 context) => context.prev1;
}

/// Context state for an order-2 model (depends on the previous two symbols).
///
/// Stores the last symbol (`prev1`) and the one before it (`prev2`).
class ContextStateOrder2 extends ContextState {
  int prev2;
  int prev1;

  ContextStateOrder2(this.prev2, this.prev1);

  @override
  int get order => 2;

  void update(int symbol) {
    prev2 = prev1;
    prev1 = symbol;
  }
}

/// Order-2 context model (depends on the previous two symbols).
///
/// Maintains one lazily-allocated frequency distribution per `(prev2, prev1)`
/// pair, flattened into a single `size²` slot table.
class ContextModelOrder2 extends _LazyContextModel<ContextStateOrder2> {
  ContextModelOrder2(int precision, int size)
    : super(precision, size, size * size);

  @override
  int get order => 2;

  @override
  ContextStateOrder2 initialContext() => ContextStateOrder2(eof, eof);

  @override
  void updateContext(ContextStateOrder2 prevContext, int symbol) {
    prevContext.update(symbol);
  }

  @override
  int contextIndex(ContextStateOrder2 context) =>
      context.prev2 * size + context.prev1;
}

/// Context state for an order-3 model (depends on the previous three symbols).
class ContextStateOrder3 extends ContextState {
  int prev3;
  int prev2;
  int prev1;

  ContextStateOrder3(this.prev3, this.prev2, this.prev1);

  @override
  int get order => 3;

  void update(int symbol) {
    prev3 = prev2;
    prev2 = prev1;
    prev1 = symbol;
  }
}

/// Order-3 context model (depends on the previous three symbols).
///
/// To keep the context space manageable the oldest symbol (`prev3`) is bucketed
/// by [order3ShrinkFactor]. Trees are still allocated lazily, so only contexts
/// actually visited consume memory.
class ContextModelOrder3 extends _LazyContextModel<ContextStateOrder3> {
  /// Factor used to reduce the size of the order-3 model.
  ///
  /// The `prev3` dimension is divided by this value to produce a smaller,
  /// memory-efficient table for third-order contexts.
  final int order3ShrinkFactor;

  ContextModelOrder3(int precision, int size, {this.order3ShrinkFactor = 32})
    : super(precision, size, ((size ~/ order3ShrinkFactor) + 1) * size * size);

  @override
  int get order => 3;

  @override
  ContextStateOrder3 initialContext() => ContextStateOrder3(eof, eof, eof);

  @override
  void updateContext(ContextStateOrder3 prevContext, int symbol) {
    prevContext.update(symbol);
  }

  @override
  int contextIndex(ContextStateOrder3 context) =>
      ((context.prev3 ~/ order3ShrinkFactor) * size + context.prev2) * size +
      context.prev1;
}
