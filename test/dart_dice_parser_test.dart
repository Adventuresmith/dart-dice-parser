import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRandom extends Mock implements Random {}

void main() {
  late Random staticMockRandom;
  late Random seededRandom;

  setUp(() async {
    // first 100 seeded rolls for d6
    // [6, 2, 1, 5, 3, 5, 1, 4, 6, 5, 6, 4, 2, 4, 2, 3, 5, 1, 1, 2, 4, 1, 6, 2, 2, 5, 6, 3, 1, 3, 6, 1, 2, 3, 6, 2, 1, 1, 1, 3, 1, 2, 3, 3, 6, 2, 5, 4, 3, 4, 1, 5, 4, 4, 2, 6, 5, 4, 6, 2, 3, 1, 4, 5, 3, 2, 2, 6, 6, 4, 4, 2, 6, 2, 5, 3, 3, 4, 4, 2, 2, 4, 3, 2, 6, 6, 4, 6, 4, 4, 3, 1, 4, 2, 2, 4, 3, 3, 1, 3]
    seededRandom = Random(1234);
    staticMockRandom = MockRandom();
    // NOTE: this mocks the random number generator to always return '1'
    //    -- that means the dice-roll is '2' (since rolls are 1-based)
    when(
      () => staticMockRandom.nextInt(any()),
    ).thenReturn(1);
  });
  void staticRandTest(String name, String input, int expected) {
    test("$name - $input", () {
      expect(
        DiceExpression.create(input, staticMockRandom).roll(),
        equals(expected),
      );
    });
  }

  void seededRandTest(String name, String input, int expected) {
    test("$name - $input", () {
      expect(
        DiceExpression.create(input, seededRandom).roll(),
        equals(expected),
      );
    });
  }

  group("arithmetic", () {
    staticRandTest("addition", "1+20", 21);
    staticRandTest("multi", "3*2", 6);
    staticRandTest("parens", "(5+6)*2", 22);
    staticRandTest("order of operations", "5+6*2", 17);
  });
  group("debug", () {
    seededRandTest("count =", "4d6#=1", 1);
  });

  group("counting operations", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("count >", "4d6#>3", 2);
    seededRandTest("count <", "4d6#>1", 3);
    seededRandTest("count =", "4d6#=1", 1);
    seededRandTest("count > (missing from result)", "4d6#>6", 0);
    seededRandTest("count #", "4d6#", 4);
    seededRandTest("count # after drop", "4d6-<2#", 3);
  });
  group("roll modifiers - drop, clamp, etc", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("drop high", "4d6-H", 8);
    seededRandTest("drop high (lowercase)", "4d6-h", 8);
    seededRandTest("drop high (1)", "4d6-h1", 8);
    seededRandTest("drop high (3)", "4d6-h3", 1);
    seededRandTest("drop low", "4d6-L", 13);
    seededRandTest("drop low (lower)", "4d6-l", 13);
    seededRandTest("drop low - 1", "4d6-l1", 13);
    seededRandTest("drop low - 3", "4d6-l3", 6);
    seededRandTest("drop low and high", "4d6-L-H", 7);
    seededRandTest("dropping an int drops all", "4-L3", 0);
    seededRandTest("can drop more than rolled", "3d6-H4", 0);
    seededRandTest("can drop more than rolled", "3d6-l4", 0);
    seededRandTest("drop >3", "4d6->3", 3);
    seededRandTest("drop <3", "4d6-<3", 11);
    seededRandTest("drop =2", "4d6-=2", 12);
    seededRandTest("drop =4 (not in results)", "4d6-=4", 14);
    seededRandTest("clamp > 3", "4d6C>3", 9);
    seededRandTest("clamp < 3", "4d6C<3", 17);
    seededRandTest("clamp > 3 lowercase", "4d6c>3", 9);
    seededRandTest("clamp < 3 lowercase", "4d6c<3", 17);

    // mocked responses should return rolls of 6, 2, 1, 5, 3
    // [6,2] + [1,5,3] = [6,2,1,5,3]-L3 => [6,5] = 9
    seededRandTest("drop low on aggregated dice", "(2d6+3d6)-L3", 11);
  });
  group("addition combines", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest(
      "addition combines results (drop is higher order than plus)",
      "3d6+1d6-L1",
      9,
    );
    seededRandTest("addition combines results - parens", "(2d6+2d6)-L1", 13);
    seededRandTest("addition combines results", "(2d6+1)-L1", 8);
  });

  group("mult variations", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("int mult on rhs", "2d6*2", 16);
    seededRandTest("int mult on lhs", "2*2d6", 16);
    // mult collapses into single result, so dropping will wind up w/ zero return
    seededRandTest("dropped multiplied results", "(2d6*2)-L", 0);
  });
  group("missing ints", () {
    staticRandTest("empty string returns zero", "", 0);
    staticRandTest("empty arith returns zero - add", "+", 0);
    staticRandTest("empty arith returns zero - mult", "*", 0);
    staticRandTest("empty ndice is 1", "d6", 2);
    staticRandTest("whitespace should be swallowed", "2 d6", 4);
    staticRandTest("whitespace should be swallowed", "2d 6", 4);
    // weird because mocked random returns '2'
    staticRandTest("empty nsides is 1", "6d", 12);
  });

  group("dice", () {
    staticRandTest("order of operations, with dice", "5 + 6 * 2d6", 29);

    staticRandTest("simple roll", "1d6", 2);
    staticRandTest("percentile", "1d%", 2);
    staticRandTest("D66", "1D66", 22);
    staticRandTest("d66 -- 66-sided, not D66", "1d66", 2);
    staticRandTest("ndice in parens", "(4+6)d10", 20);
    staticRandTest("nsides in parens", "10d(2*3)", 20);

    staticRandTest("zero dice rolled", "0d6", 0);

    staticRandTest("dice expr as sides", "2d(3d6)", 4);

    staticRandTest("fudge", "4dF", -4);
    // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
    // 2nd roll: 5,6 (explodes 1) (total 11)
    // 3rd roll: 4 (explodes 0) (total 4)
    seededRandTest("exploding dice", "9d!6", 48);

    // explode, then count 6's
    seededRandTest("exploding dice and count", "9d!6#=6", 3);
    // explode, then drop less-than-6, then count (should be identical to above)
    seededRandTest("exploding dice and count variation", "9d!6-<6#", 3);

    // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
    // 2nd roll: 5,6 (a six, but shouldn't explode) (total 11)
    seededRandTest("limited exploding dice", "9d!!6", 44);

    test("invalid dice str", () {
      expect(
        () => DiceExpression.create("1d5 + x2", staticMockRandom).roll(),
        throwsFormatException,
      );
    });

    test("rollN test", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('2d6', seededRandom);

      expect(
        dice.rollN(2),
        emitsInOrder([
          8,
          6,
          emitsDone,
        ]),
      );
    });

    test("stats test", () async {
      final dice = DiceExpression.create('2d6', seededRandom);

      final stats = await dice.stats(num: 100);

      expect(
        stats,
        equals({
          'mean': 6.65,
          'stddev': 2.35,
          'min': 2,
          'max': 12,
          'count': 100,
          'histogram': {
            2: 3,
            3: 6,
            4: 12,
            5: 10,
            6: 20,
            7: 10,
            8: 18,
            9: 9,
            10: 7,
            11: 2,
            12: 3
          }
        }),
      );
    });
  });
}
