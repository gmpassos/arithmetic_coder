import 'dart:typed_data';

import 'package:arithmetic_coder/arithmetic_coder.dart';
import 'package:arithmetic_coder/src/context_model.dart';
import 'package:test/test.dart';

void main() {
  for (var order = 0; order <= ContextModel.maxContextOrder; ++order) {
    _testsWithOrder(order);
  }
}

void _testsWithOrder(int order) {
  group('ArithmeticCoder(order: $order)', () {
    final ac = ArithmeticCoder(order: order);

    test('Context model order', () {
      expect(ac.order, equals(order));
    });

    test('encode and decode empty input', () {
      final input = Uint8List(0);

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, isEmpty);
    });

    test('encode and decode single byte', () {
      final input = Uint8List.fromList([42]);

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));
    });

    test('encode and decode multiple bytes', () {
      final input = Uint8List.fromList([1, 2, 3, 4, 5, 255, 0, 128]);

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));
    });

    test('encode and decode repeated bytes', () {
      final input = Uint8List.fromList(List.filled(100, 7));

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));
    });

    test('encode and decode random bytes', () {
      final input = Uint8List.fromList(List.generate(256, (i) => i));

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));
    });

    test('encoded size is smaller than input for repeated patterns', () {
      final input = Uint8List.fromList(List.filled(1024, 42));

      final encoded = ac.encode(input);

      expect(encoded.length, lessThan(input.length));
    });

    test('encode and decode big repeated text', () {
      // Base text (can be any long string)
      const baseText =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ';

      // Multiply to increase size
      final repeatCount = 500; // adjust for desired size (~55KB)
      final largeText = baseText * repeatCount;

      final input = Uint8List.fromList(largeText.codeUnits);

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));

      print('Original size: ${input.length} bytes');
      print('Encoded size: ${encoded.length} bytes');
    });

    test('encode and decode larger repeated text', () {
      // Base text (can be any long string)
      const baseText =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ';

      // Multiply to increase size
      final repeatCount = 5000; // adjust for desired size (~550KB)
      final largeText = baseText * repeatCount;

      final input = Uint8List.fromList(largeText.codeUnits);

      final encoded = ac.encode(input);
      final decoded = ac.decode(encoded);

      expect(decoded, equals(input));

      print('Original size: ${input.length} bytes');
      print('Encoded size: ${encoded.length} bytes');
    });
  });
}
