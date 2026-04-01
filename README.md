# arithmetic_coder

[![pub package](https://img.shields.io/pub/v/arithmetic_coder.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/arithmetic_coder)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/arithmetic_coder?logo=git&logoColor=white)](https://github.com/gmpassos/arithmetic_coder/releases)
[![Last Commit](https://img.shields.io/github/last-commit/gmpassos/arithmetic_coder?logo=github&logoColor=white)](https://github.com/gmpassos/arithmetic_coder/commits/master)
[![License](https://img.shields.io/github/license/gmpassos/arithmetic_coder?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/arithmetic_coder/blob/master/LICENSE)

`arithmetic_coder` is a pure Dart implementation of **adaptive arithmetic coding** with **context modeling**, designed for efficient lossless compression of byte streams.

It combines:

* 📊 Adaptive probability modeling
* 🧠 Finite-order context models (order 0, 1, 2)
* 🌲 Fenwick Tree (Binary Indexed Tree) for fast cumulative frequencies
* 🔢 Bit-level I/O (BitReader / BitWriter)
* ⚖️ Automatic rescaling to prevent overflow

---

## Features

* ✅ Adaptive (no pre-trained model required)
* 🧠 Context modeling (order 0, 1, 2)
* ⚡ Efficient O(log n) updates via Fenwick tree
* 📦 Byte-level compression and decompression
* 🔁 Streaming-friendly design
* 🔍 Deterministic decoding with mirrored context state

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  arithmetic_coder: ^latest
```

---

## Usage

### Encode

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:arithmetic_coder/arithmetic_coder.dart';

void main() {
  final input = Uint8List.fromList(utf8.encode('Hello world'));

  final ac = ArithmeticCoder(order: 2);
  final compressed = ac.encode(input);

  print('Original   : ${input.length} bytes');
  print('Compressed : ${compressed.length} bytes');
}
```

---

### Decode

```dart
import 'dart:convert';

final ac = ArithmeticCoder(order: 2);
final decompressed = ac.decode(compressed);

print(utf8.decode(decompressed));
```

---

## How It Works

### 1. Range Encoding

Each symbol narrows a `[low, high]` range based on its probability:

```
range = high - low + 1
high = low + (range * cumulativeHigh / total) - 1
low  = low + (range * cumulativeLow  / total)
```

---

### 2. Renormalization

To maintain precision, the coder emits bits when:

* range falls entirely in lower half → emit `0`
* range falls entirely in upper half → emit `1`
* range is in the middle → defer bits (underflow handling)

---

### 3. Context Modeling

The coder adapts probabilities based on previous symbols using a finite-order Markov model:

* **Order 0** → no context (global distribution)
* **Order 1** → previous symbol
* **Order 2** → previous two symbols

Each context maintains its own adaptive frequency table.

```dart
final ac = ArithmeticCoder(order: 1);
```

---

### 4. Adaptive Model

Frequencies are updated after each symbol:

```dart
model.update(symbol);
```

* Starts with uniform distribution
* Learns symbol probabilities dynamically
* Rescales when totals exceed a threshold

---

### 5. Fenwick Tree

Efficiently supports:

* prefix sums → cumulative frequencies
* updates → O(log n)
* inverse lookup → symbol decoding

---

## Arithmetic Coding Overview

**Arithmetic coding** is a lossless compression technique that encodes an entire message as a single number within a fractional interval `[0, 1)`.

Instead of assigning fixed bit patterns to symbols (like Huffman coding), it:

* Encodes the whole sequence into a continuously refined numeric range
* Uses symbol probabilities to narrow that range step by step
* Achieves compression close to the entropy limit

### Key Idea

Each symbol reduces the interval:

```
[low, high) → progressively narrower range
```

The final value uniquely represents the entire message.

### Why It’s Powerful

* Near-optimal compression efficiency
* Handles fractional probabilities naturally
* Benefits significantly from context modeling

---

## API Overview

### ArithmeticCoder

```dart
ArithmeticCoder({int order = 0});

Uint8List encode(Uint8List input);
Uint8List decode(Uint8List input);
```

---

### Core Components

* `ArithmeticCoder` → encoder/decoder
* `ContextModel` → context-aware probability model
* `Fenwick` → frequency structure
* `BitWriter` → bit-level output
* `BitReader` → bit-level input

---

## Example

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:arithmetic_coder/arithmetic_coder.dart';

void main() {
  final text = 'Dart is awesome! ' * 100;
  final input = Uint8List.fromList(utf8.encode(text));

  final ac = ArithmeticCoder(order: 2);

  final encoded = ac.encode(input);
  final decoded = ac.decode(encoded);
  
  final ratio = encoded.length / input.length;

  print('Original   : ${input.length} bytes');
  print('Encoded    : ${encoded.length} bytes');
  print('Decoded    : ${decoded.length} bytes');
  print('Ratio      : $ratio');
}
```

---

## Limitations

* Pure Dart (no SIMD / native optimizations)
* No built-in file streaming (yet)
* Higher memory usage for higher-order models (especially order 2)

---

## Roadmap

* Streaming API
* Higher-order / PPM models
* Performance tuning
* Optional static models

---

## Contributing

Contributions are welcome:

* Bug reports
* Performance improvements
* New modeling strategies
* Documentation improvements

---

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

---

## Sponsor

If you find this project useful, consider supporting it through [GitHub Sponsors][github_sponsors].

Your support helps keep the project active, maintained, and continuously improving.

Thank you! 🚀

[github_sponsors]: https://github.com/sponsors/gmpassos

---

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
