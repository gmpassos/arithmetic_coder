import 'package:arithmetic_coder/src/bit_writer.dart';
import 'package:test/test.dart';

void main() {
  group('BitWriter', () {
    test('write single bits and flush to bytes', () {
      final writer = BitWriter();
      final bits = [1, 0, 1, 1, 0, 0, 1, 0]; // -> 0xB2
      for (var bit in bits) {
        writer.writeBit(bit);
      }
      expect(writer.bytes, [0xB2]);
    });

    test('write fewer than 8 bits then flush', () {
      final writer = BitWriter();
      writer.writeBit(1);
      writer.writeBit(0);
      writer.writeBit(1);
      writer.flush();
      expect(writer.bytes, [0xA0]); // 10100000
    });

    test('write fewer than 8 bits then flushFinal pads correctly', () {
      final writer = BitWriter();
      writer.writeBit(1);
      writer.writeBit(0);
      writer.writeBit(1);
      writer.flushFinal(0, 4);
      expect(writer.bytes, [0xA8]); // 10101000
    });

    test('pending bits are written as flipped bits', () {
      final writer = BitWriter();
      writer.writePending(); // pending++
      writer.writeBit(1); // not flushed yet
      expect(writer.bytes, isEmpty);
      writer.flush(); // flushes one 0 after 1
      expect(writer.bytes, [0x80]); // 10000000
    });

    test('flushFinal writes correct bit based on low vs quarter', () {
      final writer0 = BitWriter();
      writer0.flushFinal(0, 4); // low < quarter -> write 01
      expect(writer0.bytes, [64]);

      final writer1 = BitWriter();
      writer1.flushFinal(5, 4); // low >= quarter -> write 1
      expect(writer1.bytes, [0x80]);
    });

    test('write multiple pending bits', () {
      final writer = BitWriter();
      writer.writePending();
      writer.writePending(); // 2 pending
      writer.writeBit(0); // writes 11+0
      expect(writer.bytes, isEmpty);
      writer.flushFinal(0, 4); //  flushes 1101
      expect(writer.bytes, [104]); // 1101000
    });
  });
}
