import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRandom extends Mock implements Random {}

void main() {
  // dice parser whose random always returns '1' (rolls '2')
  late DiceParser staticDiceParser;
  late DiceParser seededDiceParser;

  setUp(() async {
    // first 100 seeded rolls for d6
    // [6, 2, 1, 5, 3, 5, 1, 4, 6, 5, 6, 4, 2, 4, 2, 3, 5, 1, 1, 2, 4, 1, 6, 2, 2, 5, 6, 3, 1, 3, 6, 1, 2, 3, 6, 2, 1, 1, 1, 3, 1, 2, 3, 3, 6, 2, 5, 4, 3, 4, 1, 5, 4, 4, 2, 6, 5, 4, 6, 2, 3, 1, 4, 5, 3, 2, 2, 6, 6, 4, 4, 2, 6, 2, 5, 3, 3, 4, 4, 2, 2, 4, 3, 2, 6, 6, 4, 6, 4, 4, 3, 1, 4, 2, 2, 4, 3, 3, 1, 3]
    final seededRandom = Random(1234);
    final staticMockRandom = MockRandom();
    // NOTE: this mocks the random number generator to always return '1'
    //    -- that means the dice-roll is '2' (since rolls are 1-based)
    when(
      () => staticMockRandom.nextInt(any()),
    ).thenReturn(1);

    staticDiceParser = DiceParser(staticMockRandom);
    seededDiceParser = DiceParser(seededRandom);
  });

  group("arithmetic", () {
    test("addition", () {
      expect(staticDiceParser.roll("1 + 20"), equals(21));
    });

    test("subtraction", () {
      expect(staticDiceParser.roll("1 - 20"), equals(-19));
    });

    test("multi", () {
      expect(staticDiceParser.roll("3 * 2"), equals(6));
    });

    test("parens", () {
      expect(staticDiceParser.roll("(5 + 6) * 2"), equals(22));
    });

    test("order of operations", () {
      expect(staticDiceParser.roll("5 + 6 * 2"), equals(17));
    });
  });

  group("counting operations", () {
    test("count >", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6#>3"), equals(2));
    });
    test("count <", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6#<4"), equals(2));
    });
    test("count =", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6#=1"), equals(1));
    });
    test("count > (missing)", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6#>6"), equals(0));
    });

    test("count #", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6#"), equals(4));
    });
    test("count # after drop", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-<2#"), equals(3));
    });
  });
  group("roll modifiers - drop, clamp, etc", () {
    test("drop high", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-H"), equals(8));
    });
    test("drop high (lowercase)", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-h"), equals(8));
    });
    test("drop high - 1", () {
      // equivalent to the above
      expect(seededDiceParser.roll("4d6-H1"), equals(8));
    });
    test("drop high - 3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-H3"), equals(1));
    });
    test("drop low", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-L"), equals(13));
    });

    test("drop low (lowercase)", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-l"), equals(13));
    });
    test("drop low - 1", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-L1"), equals(13));
    });
    test("drop low and high", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-L-H"), equals(7));
    });
    test("drop low - 3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-L3"), equals(6));
    });
    test("drop low on aggregated dice", () {
      // mocked responses should return rolls of 6, 2, 1, 5, 3
      // [6,2] + [1,5,3] = [6,2,1,5,3]-L3 => [6,5] = 9
      expect(seededDiceParser.roll("(2d6+3d6)-L3"), equals(11));
    });
    test("drop on int has no effect", () {
      expect(seededDiceParser.roll("4-L3"), equals(4));
    });
    test("can drop more than rolled", () {
      expect(seededDiceParser.roll("3d6-H4"), equals(0));
    });
    test("can drop more than rolled (low)", () {
      expect(seededDiceParser.roll("3d6-L4"), equals(0));
    });
    test("drop >3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6->3"), equals(3));
    });
    test("drop <3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-<3"), equals(11));
    });
    test("drop =2", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6-=2"), equals(12));
    });
    test("clamp >3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6C>3"), equals(9));
    });
    test("clamp <3", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6C<3"), equals(17));
    });
    test("clamp >3 (lowercase)", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6c>3"), equals(9));
    });
    test("clamp <3 (lowercase)", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      //
      expect(seededDiceParser.roll("4d6c<3"), equals(17));
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
      // multiply first, then add
      expect(staticDiceParser.roll("5 + 6 * 2d6"), equals(29));
    });

    test("simple roll", () {
      expect(staticDiceParser.roll("1d6"), equals(2));
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
      expect(staticDiceParser.roll("(4+6)d10"), equals(20));
    });

    test("nsides in parens", () {
      expect(staticDiceParser.roll("10d(2*3)"), equals(20));
    });

    test("zero dice rolled", () {
      expect(staticDiceParser.roll("0d6"), equals(0));
    });
    test("nsides in parens (throws because negative)", () {
      expect(() => staticDiceParser.roll("10d(1-5)"), throwsRangeError);
    });
    test("ndice in parens (throws because negative)", () {
      expect(() => staticDiceParser.roll("(1-5)d6"), throwsRangeError);
    });

    test("dice expr as sides", () {
      expect(staticDiceParser.roll("2d(3d6)"), equals(4));
    });

    test("fudge", () {
      expect(staticDiceParser.roll("4dF"), equals(-4));
    });
    test("exploding dice", () {
      // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
      // 2nd roll: 5,6 (explodes 1) (total 11)
      // 3rd roll: 4 (explodes 0) (total 4)
      expect(seededDiceParser.roll("9d!6"), equals(48));
    });

    test("exploding dice and count", () {
      // explode, then count 6's
      expect(seededDiceParser.roll("9d!6#=6"), equals(3));
    });
    test("exploding dice and count variation", () {
      // explode, then drop less-than-6, then count (should be identical to above)
      expect(seededDiceParser.roll("9d!6-<6#"), equals(3));
    });

    test("limited exploding dice", () {
      // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
      // 2nd roll: 5,6 (a six, but shouldn't explode) (total 11)
      expect(seededDiceParser.roll("9d!!6"), equals(44));
    });

    test("invalid dice str", () {
      expect(() => staticDiceParser.roll("1d5 + x2"), throwsFormatException);
    });
  });
}
