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
