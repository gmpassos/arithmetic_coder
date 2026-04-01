import 'dart:convert';

import 'package:arithmetic_coder/arithmetic_coder.dart';

void main() {
  final text0 = 'Hello arithmetic coding!';

  final text = '$text0\n${text0.toLowerCase()}\n${text0.toUpperCase()}\n' * 3;

  // Encode
  final input = utf8.encode(text);

  final ac = ArithmeticCoder();
  final compressed = ac.encode(input);

  // Decode
  final decompressed = ac.decode(compressed);
  final output = utf8.decode(decompressed);

  final ratio = compressed.length / input.length;

  print('Original (${text.length} bytes):\n$text');

  print('Encoded  : ${compressed.length} bytes');
  print('Ratio    : $ratio\n');

  print('Decoded (${output.length} bytes):\n$output');
}
