# arithmetic_coder

[![pub package](https://img.shields.io/pub/v/arithmetic_coder.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/arithmetic_coder)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/arithmetic_coder?logo=git&logoColor=white)](https://github.com/gmpassos/arithmetic_coder/releases)
[![Last Commit](https://img.shields.io/github/last-commit/gmpassos/arithmetic_coder?logo=github&logoColor=white)](https://github.com/gmpassos/arithmetic_coder/commits/master)
[![License](https://img.shields.io/github/license/gmpassos/arithmetic_coder?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/arithmetic_coder/blob/master/LICENSE)

`arithmetic_coder` is a pure Dart implementation of **adaptive arithmetic coding**, designed for efficient lossless compression of byte streams.

It combines:

* 📊 Adaptive probability modeling
* 🌲 A Fenwick Tree (Binary Indexed Tree) for fast cumulative frequencies
* 🔢 Bit-level I/O (BitReader / BitWriter)
* ⚖️ Automatic rescaling to prevent overflow

---

## Features

* ✅ Adaptive (no pre-trained model required)
* ⚡ Efficient O(log n) symbol updates via Fenwick tree
* 📦 Byte-level compression and decompression
* 🔁 Streaming-friendly design
* 🧠 Suitable for experimentation, research, and production use

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

  final ac = ArithmeticCoder();
  final compressed = ac.encode(input);

  print('Original: ${input.length} bytes');
  print('Compressed: ${compressed.length} bytes');
}
```

---

### Decode

```dart
import 'dart:convert';

final ac = ArithmeticCoder();
final decompressed = ac.decode(compressed);

print(utf8.decode(decompressed)); // Hello world
```

---

## How It Works

### 1. Range Encoding

Each symbol narrows a `[low, high]` range based on its probability:

```
range = high - low + 1
high = low + (range * cumulative_high / total) - 1
low  = low + (range * cumulative_low  / total)
```

---

### 2. Renormalization

To maintain precision, the coder emits bits when:

* range falls entirely in lower half → emit `0`
* range falls entirely in upper half → emit `1`
* range is in the middle → defer bits (underflow handling)

---

### 3. Adaptive Model

Frequencies are updated after each symbol:

```dart
fenwick.update(symbol);
```

* Starts with uniform distribution
* Learns symbol probabilities dynamically
* Rescales when total exceeds a threshold

---

### 4. Fenwick Tree

Efficiently supports:

* prefix sums → cumulative frequencies
* updates → O(log n)
* inverse lookup → symbol decoding

---

## Arithmetic Coding Overview

**Arithmetic coding** is a lossless compression technique that represents an entire message as a single number within a fractional interval `[0, 1)`.

Instead of assigning fixed bit patterns to symbols (like Huffman coding), arithmetic coding:

* Encodes the whole sequence into a continuously refined numeric range
* Uses symbol probabilities to narrow that range step by step
* Produces highly efficient compression, especially for skewed distributions

### Key Idea

Each symbol reduces the interval:

```
[low, high) → narrower range based on symbol probability
```

The final number uniquely represents the entire message.

### Why It’s Powerful

* Achieves compression closer to the theoretical entropy limit
* Handles fractional probabilities naturally
* Works especially well with adaptive models

### Learn More

For a deeper explanation, see:

* [https://en.wikipedia.org/wiki/Arithmetic_coding](https://en.wikipedia.org/wiki/Arithmetic_coding)

---

## API Overview

### ArithmeticCoder

```dart
Uint8List encode(Uint8List input);
Uint8List decode(Uint8List input);
```

---

### Core Components

* `ArithmeticCoder` → encoder/decoder
* `Fenwick` → adaptive frequency model
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

  final input = utf8.encode(text);

  final encoded = ArithmeticCoder.encode(input);
  final decoded = ArithmeticCoder.decode(encoded);

  print(input.length); // original size
  print(encoded.length); // compressed size
  print(decoded.length); // restored size
}
```

---

## Limitations

* Not optimized for SIMD or native performance (pure Dart)
* No built-in file streaming (yet)
* Uses order-0 model (no context modeling)

---

## Contributing

Contributions are welcome!

* Bug reports
* Performance improvements
* New models (order-1, PPM, etc.)
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
