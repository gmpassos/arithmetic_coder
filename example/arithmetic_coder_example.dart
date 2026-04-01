import 'dart:convert';

import 'package:arithmetic_coder/arithmetic_coder.dart';

void main() {
  final text0 = 'Hello arithmetic coding!';

  final text = '$text0\n${text0.toLowerCase()}\n${text0.toUpperCase()}\n' * 10;

  final input = utf8.encode(text);

  final ac = ArithmeticCoder(order: 2);

  // Encode
  final compressed = ac.encode(input);

  // Decode
  final decompressed = ac.decode(compressed);
  final output = utf8.decode(decompressed);

  print('Original (${text.length} bytes):\n$text');

  print('------------------------\n');

  print('Decoded (${output.length} bytes):\n$output');

  print('------------------------\n');

  final ratio = compressed.length / input.length;
  var ok = _listEquals(input, decompressed);

  print('$ac\n');

  print('Original     : ${input.length} bytes');
  print('Encoded      : ${compressed.length} bytes');
  print('Decoded      : ${decompressed.length} bytes');
  print('Integrity OK : $ok');
  print('Ratio        : $ratio\n');
}

bool _listEquals(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
