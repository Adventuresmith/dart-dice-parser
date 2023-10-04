import 'dart:convert';
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
        DiceExpression.create(input, staticMockRandom).roll().total,
        equals(expected),
      );
    });
  }

  void seededRandTest(
    String name,
    String input,
    int? total, {
    List<int>? results,
    Map<String, Object>? metadata,
  }) {
    test("$name - $input", () {
      final roll = DiceExpression.create(input, seededRandom).roll();
      if (total != null) {
        expect(
          roll.total,
          equals(total),
          reason: "mismatching total",
        );
      }
      if (results != null) {
        expect(
          roll.results,
          equals(results),
          reason: "mismatching results",
        );
      }
      if (metadata != null) {
        metadata.forEach((key, value) {
          expect(
            roll.metadata[key],
            equals(value),
            reason: "mismatching metadata $key",
          );
        });
      }
    });
  }

  group("arithmetic", () {
    seededRandTest("addition", "1+20", 21);
    seededRandTest("multi", "3*2", 6);
    seededRandTest("parens", "(5+6)*2", 22);
    seededRandTest("order of operations", "5+6*2", 17);
    seededRandTest("subtraction", "5-6", -1);
    seededRandTest("subtraction", "5-6", -1);
    seededRandTest("subtraction", "1-", 1);
    seededRandTest("subtraction", "1-0", 1);
    seededRandTest("subtraction", "0-1", -1);
    seededRandTest("subtraction", "-1", -1);
    seededRandTest("negative number", "-6", -6); // this will be 0-6
  });

  group("dice and arith", () {
    seededRandTest("dice", "4d6", 14, results: [6, 2, 1, 5]);
    seededRandTest("dice+", "4d6+2", 16, results: [6, 2, 1, 5, 2]);
    seededRandTest("dice*", "4d6*2", 28, results: [28]);
  });

  group("successes and failures", () {
    // count s=nsides, f=1
    seededRandTest(
      "dice",
      "4d6#s#f#cs#cf",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 1,
        RollMetadata.failures.name: 1,
        RollMetadata.critSuccesses.name: 1,
        RollMetadata.critFailures.name: 1,
      },
    );
    seededRandTest(
      "dice",
      "4d6#s6#f1",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 1,
        RollMetadata.failures.name: 1,
      },
    );
    seededRandTest(
      "dice",
      "4d6#s=6#f=1",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 1,
        RollMetadata.failures.name: 1,
      },
    );

    seededRandTest(
      "dice",
      "4d6#s>4#f<=2#cs>5#cf<2",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 2,
        RollMetadata.failures.name: 2,
        RollMetadata.critSuccesses.name: 1,
        RollMetadata.critFailures.name: 1,
      },
    );

    seededRandTest(
      "dice",
      "4d6#s>=4#f<2",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 2,
        RollMetadata.failures.name: 1,
      },
    );

    seededRandTest(
      "dice",
      "4d6#s<2#f>5",
      14,
      results: [6, 2, 1, 5],
      metadata: {
        RollMetadata.successes.name: 1,
        RollMetadata.failures.name: 1,
      },
    );
  });

  group("counting operations", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("count >", "4d6#>3", 2);
    seededRandTest("count <", "4d6#<6", 3);
    seededRandTest("count =", "4d6#=1", 1);
    seededRandTest("count <=", "4d6#<=2", 2);
    seededRandTest("count >=", "4d6#>=6", 1);
    seededRandTest("count > (missing from result)", "4d6#>6", 0);
    seededRandTest("count #", "4d6#", 4);
    seededRandTest("count # after drop", "4d6-<2#", 3);
    seededRandTest("count # after drop", "4d6#1", 1);
    seededRandTest("count # after drop", "4d6#=1", 1);
    seededRandTest("count arith result", "(4d6+1)#1", 2);

    // 1234 seed will return  [1, -1, -1, 1, 0, 1]
    seededRandTest("count fudge", "6dF#", 6);
    seededRandTest("count fudge", "6dF#=1", 3);
    seededRandTest("count fudge", "6dF#=0", 1);
    seededRandTest("count fudge", "6dF#<0", 2);
    seededRandTest("count fudge", "6dF#>0", 3);
    seededRandTest("count", "4d6#", 4);
    seededRandTest("count", "4d6#6", 1);

    final invalids = [
      '4d6#=',
      '4d6#<=',
      '4d6#>=',
      '4d6#>',
      '4d6#<',
      '4d6-=',
      '4d6 C=',
      '4d6 r=',
      '4d6 ro=',
    ];
    for (final v in invalids) {
      test("invalid count - $v", () {
        expect(
          () => DiceExpression.create(v).roll(),
          throwsFormatException,
        );
      });
    }
  });

  group("keep high/low", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("keep low missing rhs", "4d6kl", 1);
    seededRandTest("keep low", "4d6kl2", 3);
    seededRandTest("keep low", "4d6kl3", 8);
    seededRandTest("keep high missing rhs", "4d6kh", 6);
    seededRandTest("keep high", "4d6kh2", 11);
    seededRandTest("keep high", "4d6kh3", 13);
    seededRandTest("keep high missing rhs", "4d6k", 6);
    seededRandTest("keep high", "4d6k2", 11);
    seededRandTest("keep high", "4d6k3", 13);
  });

  group("roll modifiers - drop, clamp, etc", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("drop high", "4d6-H", 8);
    seededRandTest("drop high (lowercase)", "4d6-h", 8);
    seededRandTest("drop high (1)", "4d6-h1", 8);
    seededRandTest("drop high (3)", "4d6-h3", 1);
    seededRandTest("drop low", "4d6-L", 13);
    seededRandTest("drop add result", "(4d6+1)-L", 14);
    seededRandTest("drop add result", "1-L", 0);
    seededRandTest("drop low (lower)", "4d6-l", 13);
    seededRandTest("drop low - 1", "4d6-l1", 13);
    seededRandTest("drop low - 3", "4d6-l3", 6);
    seededRandTest("drop low and high", "4d6-L-H", 7);
    seededRandTest("can drop more than rolled", "3d6-H4", 0);
    seededRandTest("can drop more than rolled", "3d6-l4", 0);
    seededRandTest("can drop arith result", "(2d6+3d6)-L1", 16);
    seededRandTest(
      "can drop arith result -- diff dice sides",
      "(2d6+3d4)-L1",
      14,
    );
    seededRandTest("drop", "4d6->3", 3);
    seededRandTest("drop", "4d6-<3", 11);
    seededRandTest("drop", "4d6->=2", 1);
    seededRandTest("drop", "4d6-<=2", 11);
    seededRandTest("drop", "4d6-=2", 12);
    seededRandTest("drop (not in results)", "4d6-=4", 14);
    seededRandTest("clamp", "4d6C>3", 9);
    seededRandTest("clamp", "4d6C<3", 17);
    seededRandTest("clamp", "4d6c>3", 9);
    seededRandTest("clamp", "4d6c<3", 17);
    seededRandTest("clamp", "1 C<1", 1);
    // rolls [1,-1,-1,1]  , -1s turned to 0
    seededRandTest("clamp", "4dF C<0", 2);

    // mocked responses should return rolls of 6, 2, 1, 5, 3
    // [6,2] + [1,5,3] = [6,2,1,5,3]-L3 => [6,5] = 9
    seededRandTest("drop low on aggregated dice", "(2d6+3d6)-L3", 11);

    test("missing clamp target", () {
      expect(
        () => DiceExpression.create("6d6 C<", seededRandom).roll(),
        throwsFormatException,
      );
    });
  });

  group("addition combines", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest(
      "addition combines results (drop is higher priority than plus)",
      "3d6+1d6-L1",
      9,
    );
    seededRandTest("addition combines results - parens", "(2d6+2d6)-L1", 13);
  });

  group("mult variations", () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest("int mult on rhs", "2d6*2", 16);
    seededRandTest("int mult on lhs", "2*2d6", 16);
    seededRandTest("int mult on lhs", "(2*2d6)-l", 0);
  });

  group("missing ints", () {
    seededRandTest("empty string returns zero", "", 0);
    seededRandTest("empty arith returns zero - add", "+", 0);
    seededRandTest("empty arith returns zero - mult", "*", 0);
    seededRandTest("empty ndice is 1", "d6", 6);
    seededRandTest("whitespace should be swallowed", "2 d6", 8);
    seededRandTest("whitespace should be swallowed", "2d 6", 8);

    test("missing nsides", () {
      expect(
        () => DiceExpression.create("6d", seededRandom).roll(),
        throwsRangeError,
      );
    });
  });

  group("reroll", () {
    seededRandTest("reroll", "10d4 r=3", 35);
    seededRandTest("reroll", "10d4 r3", 35);
    seededRandTest("reroll", "10d4 r<2", 33);
    seededRandTest("reroll", "10d4 r>2", 16);
    seededRandTest("reroll", "10d4 r<=3", 40);
    seededRandTest("reroll", "10d4 r>=2", 10);

    seededRandTest("reroll", "10d4 ro=3", 35);
    seededRandTest("reroll", "10d4 ro3", 35);
    seededRandTest("reroll", "10d4 ro<2", 33);
    seededRandTest("reroll", "10d4 ro>2", 26);
    seededRandTest("reroll", "10d4 ro<=3", 34);
    seededRandTest("reroll", "10d4 ro>=2", 27);

    seededRandTest("reroll once", "8d6r>3", 15);
    seededRandTest("reroll once", "8d6ro>3", 28);
  });

  group("dice", () {
    staticRandTest("order of operations, with dice", "5 + 6 * 2d6", 29);

    seededRandTest("simple roll", "1d6", 6);
    seededRandTest("simple roll", "d6", 6);
    seededRandTest("percentile", "1d%", 96);
    seededRandTest("percentile", "d%", 96);
    seededRandTest("D66", "1D66", 62);
    seededRandTest("D66", "D66", 62);
    seededRandTest("d66 -- 66-sided, not D66", "1d66", 30);
    seededRandTest("d66 -- 66-sided, not D66", "d66", 30);
    seededRandTest("ndice in parens", "(4+6)d10", 54);
    seededRandTest("nsides in parens", "10d(2*3)", 38);

    seededRandTest("zero dice rolled", "0d6", 0);

    staticRandTest("dice expr as sides", "2d(3d6)", 4);

    seededRandTest("fudge", "4dF", 0);
    seededRandTest("fudge", "dF", 1);
    seededRandTest("fudge", "1dF", 1);

    // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
    // 2nd roll: 5,6 (explodes 1) (total 11)
    // 3rd roll: 4 (explodes 0) (total 4)
    seededRandTest("exploding dice", "9d6!", 48);
    seededRandTest("exploding dice", "9d6!6", 48);
    seededRandTest("exploding dice", "9d6!=6", 48);
    seededRandTest("exploding dice", "9d6!>=6", 48);
    seededRandTest("exploding dice", "9d6!>5", 48);

    seededRandTest("exploding dice", "9d6!o", 44);
    seededRandTest("exploding dice", "9d6!o6", 44);
    seededRandTest("exploding dice", "9d6!o=6", 44);
    seededRandTest("exploding dice", "9d6!o>=6", 44);
    seededRandTest("exploding dice", "9d6!o>5", 44);

    seededRandTest("exploding dice", "9d6!1", 44);
    seededRandTest("exploding dice", "9d6!>=5", 56);
    seededRandTest("exploding dice", "9d6!<2", 44);
    seededRandTest("exploding dice", "9d6!<=3", 54);

    seededRandTest("exploding dice", "9d6!o1", 44);
    seededRandTest("exploding dice", "9d6!o>=5", 50);
    seededRandTest("exploding dice", "9d6!o<2", 44);
    seededRandTest("exploding dice", "9d6!o<=3", 50);

    // 1st round: 6, 2, 1, 5, 3, 5, 1, 4, 6, (compounds 2) (total 33)
    // 2nd round: 5,                      6 (compounds 1) (total 11)
    // 3rd round:                         4 (compounds 0) (total 4)
    // result    11, 2, 1, 5, 3, 5, 1, 4, 16
    seededRandTest("compounding dice", "9d6!!", 48);
    seededRandTest("compounding dice", "9d6!!6", 48);
    seededRandTest("compounding dice", "9d6!!=6", 48);
    seededRandTest("compounding dice", "9d6!!>=6", 48);
    seededRandTest("compounding dice", "9d6!!>5", 48);

    seededRandTest("compounding dice", "9d6!!o", 44);
    seededRandTest("compounding dice", "9d6!!o6", 44);
    seededRandTest("compounding dice", "9d6!!o=6", 44);
    seededRandTest("compounding dice", "9d6!!o>=6", 44);
    seededRandTest("compounding dice", "9d6!!o>5", 44);

    seededRandTest("compounding dice count", "9d6!!#>6", 2);

    seededRandTest("compounding dice", "9d6!!>=5", 56);
    seededRandTest("compounding dice", "9d6!!<3", 48);
    seededRandTest("compounding dice", "9d6!!<=3", 54);
    seededRandTest("compounding dice", "9d6!!1", 44);

    seededRandTest("compounding dice", "9d6!!o>=5", 50);
    seededRandTest("compounding dice", "9d6!!o<3", 48);
    seededRandTest("compounding dice", "9d6!!o<=3", 50);
    seededRandTest("compounding dice", "9d6!!o1", 44);

    seededRandTest("explode arith result", "(9d6+3)!", 51);

    // explode, then count 6's
    seededRandTest("exploding dice and count", "9d6!#=6", 3);
    // explode, then drop less-than-6, then count (should be identical to above)
    seededRandTest("exploding dice and count variation", "9d6!-<6#", 3);

    // different dice pools can be combined
    seededRandTest("differing nsides addition", "4d4 + 4d6", 25);
    // fudge dice can be rolled
    seededRandTest("differing nsides addition", "4dF + 6dF", 2);
    // fudge dice can be added to [1, -1, -1, 1]
    seededRandTest("differing nsides addition", "4dF + 1", 1);
    seededRandTest(
      "fudge add to d6",
      "4d6+4dF",
      14,
    );
    seededRandTest("fudge add to d6", "4dF+4d6", 13);

    test("multiple rolls is multiple results", () {
      final dice = DiceExpression.create('2d6', seededRandom);
      expect(dice.roll().total, 8);
      expect(dice.roll().total, 6);
    });

    test("create dice with real random", () {
      final dice = DiceExpression.create('10d100');
      final result1 = dice.roll();
      // result will never be zero -- this test is verifying creating the expr & doing roll
      expect(result1, isNot(0));
    });

    test("string method returns expr", () {
      final dice = DiceExpression.create('2d6# + 5d6!>=5 + 5D66', seededRandom);
      expect(dice.toString(), '((((2d6)#)+((5d6)!>=5))+(5)D66)');
    });

    test("invalid dice str", () {
      expect(
        () => DiceExpression.create("1d5 + x2", seededRandom).roll(),
        throwsFormatException,
      );
    });
    final invalids = [
      "4!",
      "4dF!",
      "4dF!!",
      "4dFr",
      "4D66!",
      "4D66!!",
      "4D66 r",
    ];
    for (final i in invalids) {
      test("invalid - $i", () {
        expect(
          () => DiceExpression.create(i, seededRandom).roll(),
          throwsFormatException,
        );
      });
    }

    test("toJson", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('2d6', seededRandom);
      final obj = dice.roll().toJson();
      expect(
        obj,
        equals({
          'expression': '(2d6)',
          'total': 8,
          'nsides': 6,
          'ndice': 2,
          'results': [6, 2],
          'metadata': {},
          'left': {
            'expression': '2',
            'total': 2,
            'nsides': 0,
            'ndice': 0,
            'results': [2],
            'metadata': {},
            'left': null,
            'right': null,
          },
          'right': {
            'expression': '6',
            'total': 6,
            'nsides': 0,
            'ndice': 0,
            'results': [6],
            'metadata': {},
            'left': null,
            'right': null,
          },
        }),
      );
      final out = json.encode(obj);
      expect(
        out,
        equals(
          '{"expression":"(2d6)","total":8,"nsides":6,"ndice":2,"results":[6,2],"metadata":{},"left":{"expression":"2","total":2,"nsides":0,"ndice":0,"results":[2],"metadata":{},"left":null,"right":null},"right":{"expression":"6","total":6,"nsides":0,"ndice":0,"results":[6],"metadata":{},"left":null,"right":null}}',
        ),
      );
    });

    test("toJson - metadata", () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('4d6 #cf #cs', seededRandom);
      final obj = dice.roll().toJson();
      expect(
        obj,
        equals({
          'expression': '(((4d6)#cf)#cs)',
          'total': 14,
          'nsides': 6,
          'ndice': 4,
          'results': [6, 2, 1, 5],
          'metadata': {
            'critFailures': 1,
            'critSuccesses': 1,
          },
          'left': {
            'expression': '((4d6)#cf)',
            'total': 14,
            'nsides': 6,
            'ndice': 4,
            'results': [6, 2, 1, 5],
            'metadata': {
              'critFailures': 1,
            },
            'left': {
              'expression': '(4d6)',
              'total': 14,
              'nsides': 6,
              'ndice': 4,
              'results': [6, 2, 1, 5],
              'metadata': {},
              'left': {
                'expression': '4',
                'total': 4,
                'nsides': 0,
                'ndice': 0,
                'results': [4],
                'metadata': {},
                'left': null,
                'right': null,
              },
              'right': {
                'expression': '6',
                'total': 6,
                'nsides': 0,
                'ndice': 0,
                'results': [6],
                'metadata': {},
                'left': null,
                'right': null,
              },
            },
            'right': {
              'expression': '',
              'total': 0,
              'nsides': 0,
              'ndice': 0,
              'results': [],
              'metadata': {},
              'left': null,
              'right': null,
            },
          },
          'right': {
            'expression': '',
            'total': 0,
            'nsides': 0,
            'ndice': 0,
            'results': [],
            'metadata': {},
            'left': null,
            'right': null,
          },
        }),
      );
      final out = json.encode(obj);
      expect(
        out,
        equals(
          '{"expression":"(((4d6)#cf)#cs)","total":14,"nsides":6,"ndice":4,"results":[6,2,1,5],"metadata":{"critFailures":1,"critSuccesses":1},"left":{"expression":"((4d6)#cf)","total":14,"nsides":6,"ndice":4,"results":[6,2,1,5],"metadata":{"critFailures":1},"left":{"expression":"(4d6)","total":14,"nsides":6,"ndice":4,"results":[6,2,1,5],"metadata":{},"left":{"expression":"4","total":4,"nsides":0,"ndice":0,"results":[4],"metadata":{},"left":null,"right":null},"right":{"expression":"6","total":6,"nsides":0,"ndice":0,"results":[6],"metadata":{},"left":null,"right":null}},"right":{"expression":"","total":0,"nsides":0,"ndice":0,"results":[],"metadata":{},"left":null,"right":null}},"right":{"expression":"","total":0,"nsides":0,"ndice":0,"results":[],"metadata":{},"left":null,"right":null}}',
        ),
      );
    });

    test("rollN test", () async {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('2d6', seededRandom);

      final results =
          await dice.rollN(2).map((result) => result.total).toList();
      expect(results, equals([8, 6]));
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
            12: 3,
          },
        }),
      );
    });
  });
}
