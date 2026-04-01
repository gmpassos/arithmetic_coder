import 'dart:typed_data';

import 'package:arithmetic_coder/src/bit_reader.dart';
import 'package:test/test.dart';

void main() {
  group('BitReader', () {
    test('read single bits MSB first', () {
      // 0b10110010 -> 0xB2
      final data = Uint8List.fromList([0xB2]);
      final reader = BitReader(data);

      expect(reader.readBit(), 1);
      expect(reader.readBit(), 0);
      expect(reader.readBit(), 1);
      expect(reader.readBit(), 1);
      expect(reader.readBit(), 0);
      expect(reader.readBit(), 0);
      expect(reader.readBit(), 1);
      expect(reader.readBit(), 0);
    });

    test('read multiple bits', () {
      // 0b11001100 0b10101010 -> 0xCC, 0xAA
      final data = Uint8List.fromList([0xCC, 0xAA]);
      final reader = BitReader(data);

      expect(reader.readBits(4), int.parse('1100', radix: 2));
      expect(reader.readBits(4), int.parse('1100', radix: 2));
      expect(reader.readBits(8), int.parse('10101010', radix: 2));
    });

    test('readInitialCode', () {
      // 0b11110000 0b00001111 -> 0xF0, 0x0F
      final data = Uint8List.fromList([0xF0, 0x0F]);
      final reader = BitReader(data);

      final code = reader.readInitialCode(12); // first 12 bits: 111100000000
      expect(code, int.parse('111100000000', radix: 2));
    });

    test('reading past input returns 0', () {
      final data = Uint8List.fromList([0x80]); // 10000000
      final reader = BitReader(data);

      expect(reader.readBits(8), int.parse('10000000', radix: 2));
      expect(reader.readBit(), 0); // beyond end
      expect(reader.readBits(3), 0);
    });
  });
}
