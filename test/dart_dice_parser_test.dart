import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

import 'dart:math';

class MockRandom extends Mock implements Random {}

void main() {

  var mockRandom = new MockRandom();
  var roller = new DiceRoller(mockRandom);
  var diceParser = new DiceParser(roller);

  when(mockRandom.nextInt(argThat(inInclusiveRange(1, 1000)))).thenReturn(1);

  group("arithmetic", () {
    test("addition", () {
      var input = "1 + 20";
      expect(diceParser.roll(input), equals(21));
    });

    test("subtraction", () {
      var input = "1 - 20";
      expect(diceParser.roll(input), equals(-19));
    });

    test("multi", () {
      var input = "3 * 2";
      expect(diceParser.roll(input), equals(6));
    });

    test("parens", () {
      var input = "(5 + 6) * 2";
      expect(diceParser.roll(input), equals(22));
    });

    test("order of operations", () {
      var input = "5 + 6 * 2";
      expect(diceParser.roll(input), equals(17));
    });
  });

  group("dice", () {

    test("order of operations, with dice", () {
      var input = "5 + 6 * 2d6";
      expect(diceParser.roll(input), equals(29));
    });

    test("simple roll", () {
      var input = "1d6";
      expect(diceParser.roll(input), equals(2));
    });

    test("ndice in parens", () {
      var input = "(4+6)d10";
      expect(diceParser.roll(input), equals(20));
    });

    test("nsides in parens", () {
      var input = "10d(2*3)";
      expect(diceParser.roll(input), equals(20));
    });

    test("fudge", () {
      var input = "4dF";
      expect(diceParser.roll(input), equals(-4));
    });

    test("invalid dice str", () {
      var input = "1d5 + x2";
      expect(() => diceParser.roll(input), throwsFormatException);
    });

  }
  );
}
