import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockRandom extends Mock implements Random {}

void main() {
  // dice parser whose random always returns '1' (rolls '2')
  DiceParser staticDiceParser;
  // dice parser whose random returns incrementing ints from 0, 1, 2... (rolls 1,2,3...)
  DiceParser incrementingDiceParser;

  setUp(() async {
    var staticMockRandom = MockRandom();
    var incrementingMockRandom = MockRandom();
    // NOTE: this mocks the random number generator to always return '1'
    //    -- that means the dice-roll is '2' (since rolls are 1-based)
    when(staticMockRandom.nextInt(argThat(inInclusiveRange(1, 1000))))
        .thenReturn(1);

    var responses = Iterable.generate(1000).toList();
    // mock Random to return 0-1000 inclusive.
    when(incrementingMockRandom.nextInt(argThat(inInclusiveRange(1, 1000))))
        .thenAnswer((_) => responses.removeAt(0));

    staticDiceParser = DiceParser(diceRoller: DiceRoller(staticMockRandom));
    incrementingDiceParser =
        DiceParser(diceRoller: DiceRoller(incrementingMockRandom));
  });

  group("arithmetic", () {
    test("addition", () {
      var input = "1 + 20";
      expect(staticDiceParser.roll(input), equals(21));
    });

    test("subtraction", () {
      var input = "1 - 20";
      expect(staticDiceParser.roll(input), equals(-19));
    });

    test("multi", () {
      var input = "3 * 2";
      expect(staticDiceParser.roll(input), equals(6));
    });

    test("parens", () {
      var input = "(5 + 6) * 2";
      expect(staticDiceParser.roll(input), equals(22));
    });

    test("order of operations", () {
      var input = "5 + 6 * 2";
      expect(staticDiceParser.roll(input), equals(17));
    });
  });

  group("drop high/low:", () {
    test("drop high", () {
      // mocked responses should return rolls of 1,2,3,4
      //
      expect(incrementingDiceParser.roll("4d6-H"), equals(6));
    });
    test("drop high - 1", () {
      // equivalent to the above
      expect(incrementingDiceParser.roll("4d6-H1"), equals(6));
    });
    test("drop high - 3", () {
      // mocked responses should return rolls of 1,2,3,4
      //
      expect(incrementingDiceParser.roll("4d6-H3"), equals(1));
    });
    test("drop low", () {
      // mocked responses should return rolls of 1,2,3,4
      //
      expect(incrementingDiceParser.roll("4d6-L"), equals(9));
    });
    test("drop low - 1", () {
      // mocked responses should return rolls of 1,2,3,4
      //
      expect(incrementingDiceParser.roll("4d6-L1"), equals(9));
    });
    test("drop low - 3", () {
      // mocked responses should return rolls of 1,2,3,4
      //
      expect(incrementingDiceParser.roll("4d6-L3"), equals(4));
    });
    test("drop low on aggregated dice", () {
      // mocked responses should return rolls of 1,2,3,4,5
      // [1,2] + [3,4,5] = [1,2,3,4,5]-L3 => [4,5] = 9
      expect(incrementingDiceParser.roll("(2d10+3d20)-L3"), equals(9));
    });
    test("drop on int has no effect", () {
      expect(incrementingDiceParser.roll("4-L3"), equals(4));
    });
    test("can drop more than rolled", () {
      expect(incrementingDiceParser.roll("3d6-H4"), equals(0));
    });
  });

  group("missing ints", () {
    test("empty string returns zero", () {
      expect(staticDiceParser.roll(""), equals(0));
    });
    test("empty arith returns zero - add", () {
      expect(staticDiceParser.roll("+"), equals(0));
    });
    test("empty arith returns zero - sub", () {
      expect(staticDiceParser.roll("-"), equals(0));
    });
    test("empty arith returns zero - mult", () {
      expect(staticDiceParser.roll("*"), equals(0));
    });
    test("empty ndice is 1", () {
      expect(staticDiceParser.roll("d6"), equals(2));
    });
    test("empty nsides is 1", () {
      // weird because mocked random returns '2'
      expect(staticDiceParser.roll("6d"), equals(12));
    });
    test("whitespace should be swallowed", () {
      expect(staticDiceParser.roll("2 d6"), equals(4));
      expect(staticDiceParser.roll("2d 6"), equals(4));
    });
  });

  group("dice", () {
    test("order of operations, with dice", () {
      var input = "5 + 6 * 2d6";
      expect(staticDiceParser.roll(input), equals(29));
    });

    test("simple roll", () {
      var input = "1d6";
      expect(staticDiceParser.roll(input), equals(2));
    });
    test("percentile", () {
      expect(staticDiceParser.roll("1d%"), equals(2));
    });
    test("D66", () {
      expect(staticDiceParser.roll("1D66"), equals(22));
    });
    test("d66 -- 66-sided, not D66", () {
      expect(staticDiceParser.roll("1d66"), equals(2));
    });

    test("ndice in parens", () {
      var input = "(4+6)d10";
      expect(staticDiceParser.roll(input), equals(20));
    });

    test("nsides in parens", () {
      var input = "10d(2*3)";
      expect(staticDiceParser.roll(input), equals(20));
    });
    test("dice expr as sides", () {
      var input = "2d(3d6)";
      expect(staticDiceParser.roll(input), equals(4));
    });

    test("fudge", () {
      var input = "4dF";
      expect(staticDiceParser.roll(input), equals(-4));
    });

    test("invalid dice str", () {
      var input = "1d5 + x2";
      expect(() => staticDiceParser.roll(input), throwsFormatException);
    });
  });
}
