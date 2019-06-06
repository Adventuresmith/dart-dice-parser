import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockRandom extends Mock implements Random {}

void main() {
  var mockRandom = MockRandom();
  var roller = DiceRoller(mockRandom);
  var fudgeRoller = FudgeDiceRoller(mockRandom);
  var diceParser = DiceParser(roller, fudgeRoller);

  // NOTE: this mocks the random number generator to always return '1'
  //    -- that means the dice-roll is '2' (since rolls are 1-based)
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
  group("missing ints", () {
    test("empty string returns zero", () {
      expect(diceParser.roll(""), equals(0));
    });
    test("empty arith returns zero - add", () {
      expect(diceParser.roll("+"), equals(0));
    });
    test("empty arith returns zero - sub", () {
      expect(diceParser.roll("-"), equals(0));
    });
    test("empty arith returns zero - mult", () {
      expect(diceParser.roll("*"), equals(0));
    });
    test("empty ndice is 1", () {
      expect(diceParser.roll("d6"), equals(2));
    });
    test("empty nsides is 1", () {
      // weird because mocked random returns '2'
      expect(diceParser.roll("6d"), equals(12));
    });
    test("whitespace should be swallowed", () {
      expect(diceParser.roll("2 d6"), equals(4));
      expect(diceParser.roll("2d 6"), equals(4));
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
    test("percentile", () {
      expect(diceParser.roll("1d%"), equals(2));
    });
    test("D66", () {
      expect(diceParser.roll("1D66"), equals(22));
    });
    test("d66 -- 66-sided, not D66", () {
      expect(diceParser.roll("1d66"), equals(2));
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
  });
}
