## 1.0.4

- `ArithmeticCoder`:
  - Exposed `buildContextModel` method to allow customization of the context model creation.
  - Renamed `_buildModels` to `_buildContextModelCached` and updated to use `buildContextModel`.
  - Updated `decode` method to use `models.eof` symbol dynamically instead of hardcoded `256`.

- `ContextModel` and `ContextState`:
  - Added support for order-3 context model:
    - Added `ContextStateOrder3` with three previous symbols.
    - Added `ContextModelOrder3` with a 3D Fenwick tree structure and a shrink factor to reduce memory usage.
  - Added `order` getter to `ContextState` and `ContextModel` to indicate the model order.
  - Added static `maxContextOrder` constant (value 3) to `ContextModel`.
  - Updated factory constructor in `ContextModel` to support order 3.
  - Updated all context state classes to implement `order` getter.
  - Updated all context model classes to implement `order` getter.
  - `ContextModelOrder3`:
    - Uses a 3D list of Fenwicks with size reduction on the 3rd dimension.

## 1.0.3

- `Fenwick` - reduce memory usage:
  - Updated `_tree` field initialization to use typed lists (`Uint8List`, `Uint16List`, `Uint32List`, `Uint64List`) based on the bit length of `maxTotal` for memory efficiency.
  - Added private static method `_buildIntList` to create appropriate typed list for frequency storage.
  - Adjusted `computeMaxTotal` to return `(1 << (precision ~/ 2)) - 1` instead of `1 << (precision ~/ 2)` to correctly compute maximum total frequency.
  - Changed `_tree` initialization from `List.filled` to use `_buildIntList` in constructor.

## 1.0.2

- Added context modeling support to `ArithmeticCoder`:
  - Added `order` parameter to specify finite-order Markov models (0, 1, or 2).
  - Integrated `ContextModel` abstraction with adaptive Fenwick trees per context.
  - Updated encoding and decoding to use context-dependent frequency models.
  - Added `toString` override to `ArithmeticCoder` showing order and model size.

- `ContextModel`:
  - Introduced abstract `ContextModel` with factory constructor for orders 0, 1, and 2.
  - Implemented `ContextModelOrder0`, `ContextModelOrder1`, and `ContextModelOrder2` with corresponding `ContextState` classes.
  - Each model maintains Fenwick trees for symbol frequencies per context.
  - Adaptive frequency updates and context state transitions implemented.

- `arithmetic_coder.dart`:
  - Refactored to use `ContextModel` for symbol frequency management.
  - Encoding and decoding now maintain and update context states.
  - Added detailed comments on algorithm and context modeling.

- `example/arithmetic_coder_example.dart`:
  - Updated example to use `ArithmeticCoder(order: 2)`.
  - Increased input repetition count for better compression demonstration.
  - Added output of compression ratio and integrity check.
  - Added helper `_listEquals` for byte list comparison.

- `test/arithmetic_coder_test.dart`:
  - Parameterized tests to run for orders 0, 1, and 2.
  - Removed redundant `ArithmeticCoder` instantiations inside tests.
  - Verified encode-decode correctness and compression ratio for all orders.

- `pubspec.yaml`:
  - Bumped version to `1.0.1`.

## 1.0.0

- Initial version.
