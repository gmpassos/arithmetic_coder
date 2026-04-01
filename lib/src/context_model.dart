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

      default:
        throw UnsupportedError("Unsupported order: $order");
    }
  }

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

/// Context state for an order-1 model (depends on previous symbol).
///
/// Stores the last symbol (`symbol`) and the one before it (`prev1`).
class ContextStateOrder1 extends ContextState {
  int prev1;

  ContextStateOrder1(this.prev1);

  void update(int symbol) {
    prev1 = symbol;
  }
}

/// Order-1 context model (depends on the previous symbol).
///
/// Maintains one frequency distribution per previous symbol.
class ContextModelOrder1 extends ContextModel<ContextStateOrder1> {
  final int precision;
  final int size;

  @override
  final int eof;

  late final List<Fenwick> _models;

  ContextModelOrder1(this.precision, this.size) : eof = size - 1, super._() {
    _models = List.generate(size, (i) => Fenwick(precision, size));
    assert(eof == _models.first.eof);
  }

  @override
  int get totalSize => _models.map((m) => m.size).reduce((a, b) => a + b);

  @override
  void init() {
    for (var e in _models) {
      e.init();
    }
  }

  @override
  reset() {
    for (var e in _models) {
      e.reset();
    }
  }

  @override
  ContextStateOrder1 initialContext() => ContextStateOrder1(eof);

  @override
  void updateContext(ContextStateOrder1 prevContext, int symbol) {
    prevContext.update(symbol);
  }

  @override
  Fenwick model(ContextStateOrder1 context) {
    return _models[context.prev1];
  }
}

class ContextStateOrder2 extends ContextState {
  int prev2;
  int prev1;

  ContextStateOrder2(this.prev2, this.prev1);

  void update(int symbol) {
    prev2 = prev1;
    prev1 = symbol;
  }
}

class ContextModelOrder2 extends ContextModel<ContextStateOrder2> {
  final int precision;
  final int size;

  @override
  final int eof;

  late final List<List<Fenwick>> _models;

  ContextModelOrder2(this.precision, this.size) : eof = size - 1, super._() {
    _models = List.generate(size, (i) {
      return List.generate(size, (j) => Fenwick(precision, size));
    });
    assert(eof == _models.first.first.eof);
  }

  @override
  int get totalSize => _models
      .map((l) => l.map((m) => m.size).reduce((a, b) => a + b))
      .reduce((a, b) => a + b);

  @override
  void init() {
    for (var l in _models) {
      for (var e in l) {
        e.init();
      }
    }
  }

  @override
  reset() {
    for (var l in _models) {
      for (var e in l) {
        e.reset();
      }
    }
  }

  @override
  ContextStateOrder2 initialContext() => ContextStateOrder2(eof, eof);

  @override
  void updateContext(ContextStateOrder2 prevContext, int symbol) {
    prevContext.update(symbol);
  }

  @override
  Fenwick model(ContextStateOrder2 context) {
    return _models[context.prev2][context.prev1];
  }
}
