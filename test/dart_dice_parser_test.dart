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
  void staticRandTest(String name, String input, int expectedTotal) {
    test('$name - $input', () {
      expect(
        DiceExpression.create(input, staticMockRandom).roll().total,
        equals(expectedTotal),
      );
    });
  }

  void seededRandTest(
    String testName,
    String inputExpr,
    int? expectedTotal, {
    List<int>? expectedResults,
    RollMetadata? expectedMetadata,
    int? successCount,
    int? failureCount,
    int? critSuccessCount,
    int? critFailureCount,
  }) {
    test('$testName - $inputExpr', () {
      final rollSummary = DiceExpression.create(inputExpr, seededRandom).roll();
      if (expectedTotal != null) {
        expect(
          rollSummary.total,
          equals(expectedTotal),
          reason: 'mismatching total',
        );
      }
      if (expectedResults != null) {
        expect(
          rollSummary.results,
          equals(expectedResults),
          reason: 'mismatching results',
        );
      }
      if (expectedMetadata != null) {
        expect(
          rollSummary.metadata,
          equals(expectedMetadata),
          reason: 'mismatching roll metadata',
        );
      }
      if (successCount != null) {
        expect(
          rollSummary.hasSuccesses,
          equals(successCount > 0),
          reason: 'summary missing success',
        );
        expect(
          rollSummary.metadata.score.successCount,
          equals(successCount),
          reason: 'mismatched success count',
        );
      }
      if (failureCount != null) {
        expect(
          rollSummary.hasFailures,
          equals(failureCount > 0),
          reason: 'summary missing success',
        );
        expect(
          rollSummary.metadata.score.failureCount,
          equals(failureCount),
          reason: 'mismatched success count',
        );
      }
      if (critSuccessCount != null) {
        expect(
          rollSummary.hasCritSuccesses,
          equals(critSuccessCount > 0),
          reason: 'summary missing success',
        );
        expect(
          rollSummary.metadata.score.critSuccessCount,
          equals(critSuccessCount),
          reason: 'mismatched success count',
        );
      }
      if (critFailureCount != null) {
        expect(
          rollSummary.hasCritFailures,
          equals(critFailureCount > 0),
          reason: 'summary missing success',
        );
        expect(
          rollSummary.metadata.score.critFailureCount,
          equals(critFailureCount),
          reason: 'mismatched success count',
        );
      }
    });
  }

  group('arithmetic', () {
    seededRandTest('addition', '1+20', 21);
    seededRandTest('multi', '3*2', 6);
    seededRandTest('parens', '(5+6)*2', 22);
    seededRandTest('order of operations', '5+6*2', 17);
    seededRandTest('subtraction', '5-6', -1);
    seededRandTest('subtraction', '5-6', -1);
    seededRandTest('subtraction', '1-', 1);
    seededRandTest('subtraction', '1-0', 1);
    seededRandTest('subtraction', '0-1', -1);
    seededRandTest('subtraction', '-1', -1);
    seededRandTest('negative number', '-6', -6); // this will be 0-6
  });

  group('dice and arith', () {
    seededRandTest('dice', '4d6', 14, expectedResults: [6, 2, 1, 5]);
    seededRandTest('dice+', '4d6+2', 16, expectedResults: [6, 2, 1, 5, 2]);
    seededRandTest('dice*', '4d6*2', 28, expectedResults: [28]);
  });

  group('successes and failures', () {
    // count s=nsides, f=1
    seededRandTest(
      'defaults are 1 or ndice',
      '4d6#s#f#cs#cf',
      14,
      expectedResults: const [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6],
          failures: [1],
          critSuccesses: [6],
          critFailures: [1],
        ),
      ),
      successCount: 1,
      failureCount: 1,
      critSuccessCount: 1,
      critFailureCount: 1,
    );
    seededRandTest(
      'equal sign can be omitted',
      '4d6#s6#f1',
      14,
      expectedResults: const [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6],
          failures: [1],
        ),
      ),
      successCount: 1,
      failureCount: 1,
      critSuccessCount: 0,
      critFailureCount: 0,
    );
    seededRandTest(
      'with equal sign',
      '4d6#s=6#f=1',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6],
          failures: [1],
        ),
      ),
      successCount: 1,
      failureCount: 1,
      critSuccessCount: 0,
      critFailureCount: 0,
    );

    seededRandTest(
      'dice',
      '4d6#s>4#f<=2#cs>5#cf<2',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6, 5],
          failures: [2, 1],
          critSuccesses: [6],
          critFailures: [1],
        ),
      ),
      successCount: 2,
      failureCount: 2,
      critSuccessCount: 1,
      critFailureCount: 1,
    );

    seededRandTest(
      'dice',
      '4d6#s>=4#f<2',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6, 5],
          failures: [1],
        ),
      ),
    );

    seededRandTest(
      'success low, failures high',
      '4d6#s<2#f>5',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [1],
          failures: [6],
        ),
      ),
    );
    seededRandTest(
      'critical success is also a success',
      '4d6 #s>=5 #cs=6 #f=1',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6, 5],
          failures: [1],
          critSuccesses: [6],
        ),
      ),
    );

    seededRandTest(
      'critical failure is also a failure',
      '4d6 #s>=5 #cs=6 #f<=2 #cf',
      14,
      expectedResults: [6, 2, 1, 5],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          successes: [6, 5],
          failures: [2, 1],
          critSuccesses: [6],
          critFailures: [1],
        ),
      ),
    );
  });

  group('rollVals', () {
    seededRandTest(
      '4d6 equivalent',
      '4d[1,2,3,4,5,6]',
      14,
      expectedResults: [6, 2, 1, 5],
    );
    seededRandTest(
      '4d6 equivalent - with whitespace',
      '4 d    \n[1,2 ,3,4,5,6]',
      14,
      expectedResults: [6, 2, 1, 5],
    );

    seededRandTest(
      '4d6 equivalent -- with negatives',
      '4d[-1,2,3,4,5,-6]',
      0,
      expectedResults: [-6, 2, -1, 5],
    );
  });

  group('counting operations', () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest('count >', '4d6#>3', 2);
    seededRandTest('count <', '4d6#<6', 3);
    seededRandTest('count =', '4d6#=1', 1);
    seededRandTest('count <=', '4d6#<=2', 2);
    seededRandTest('count >=', '4d6#>=6', 1);
    seededRandTest('count > (missing from result)', '4d6#>6', 0);
    seededRandTest('count #', '4d6#', 4);
    seededRandTest('count # after drop', '4d6-<2#', 3);
    seededRandTest('count # after drop', '4d6#1', 1);
    seededRandTest('count # after drop', '4d6#=1', 1);
    seededRandTest('count arith result', '(4d6+1)#1', 2);

    // 1234 seed will return  [1, -1, -1, 1, 0, 1]
    seededRandTest('count fudge', '6dF#', 6);
    seededRandTest('count fudge', '6dF#=1', 3);
    seededRandTest('count fudge', '6dF#=0', 1);
    seededRandTest('count fudge', '6dF#<0', 2);
    seededRandTest('count fudge', '6dF#>0', 3);
    seededRandTest('count', '4d6#', 4);
    seededRandTest('count', '4d6#6', 1);

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
      test('invalid count - $v', () {
        expect(
          () => DiceExpression.create(v).roll(),
          throwsFormatException,
        );
      });
    }
  });

  group('keep high/low', () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest('keep low missing rhs', '4d6kl', 1);
    seededRandTest('keep low', '4d6kl2', 3);
    seededRandTest('keep low', '4d6kl3', 8);
    seededRandTest('keep high missing rhs', '4d6kh', 6);
    seededRandTest('keep high', '4d6kh2', 11);
    seededRandTest('keep high', '4d6kh3', 13);
    seededRandTest('keep high missing rhs', '4d6k', 6);
    seededRandTest('keep high', '4d6k2', 11);
    seededRandTest('keep high', '4d6k3', 13);
  });

  group('roll modifiers - drop, clamp, etc', () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest('drop high', '4d6-H', 8);
    seededRandTest('drop high (lowercase)', '4d6-h', 8);
    seededRandTest('drop high (1)', '4d6-h1', 8);
    seededRandTest('drop high (3)', '4d6-h3', 1);
    seededRandTest('drop low', '4d6-L', 13);
    seededRandTest('drop add result', '(4d6+1)-L', 14);
    seededRandTest('drop add result', '1-L', 0);
    seededRandTest('drop low (lower)', '4d6-l', 13);
    seededRandTest('drop low - 1', '4d6-l1', 13);
    seededRandTest('drop low - 3', '4d6-l3', 6);
    seededRandTest('drop low and high', '4d6-L-H', 7);
    seededRandTest('can drop more than rolled', '3d6-H4', 0);
    seededRandTest('can drop more than rolled', '3d6-l4', 0);
    seededRandTest('can drop arith result', '(2d6+3d6)-L1', 16);
    seededRandTest(
      'can drop arith result -- diff dice sides',
      '(2d6+3d4)-L1',
      14,
    );
    seededRandTest('drop', '4d6->3', 3);
    seededRandTest('drop', '4d6-<3', 11);
    seededRandTest('drop', '4d6->=2', 1);
    seededRandTest('drop', '4d6-<=2', 11);
    seededRandTest('drop', '4d6-=2', 12);
    seededRandTest('drop (not in results)', '4d6-=4', 14);
    seededRandTest('clamp', '4d6C>3', 9);
    seededRandTest('clamp', '4d6C<3', 17);
    seededRandTest('clamp', '4d6c>3', 9);
    seededRandTest('clamp', '4d6c<3', 17);
    seededRandTest('clamp', '1 C<1', 1);
    // rolls [1,-1,-1,1]  , -1s turned to 0
    seededRandTest('clamp', '4dF C<0', 2);

    // mocked responses should return rolls of 6, 2, 1, 5, 3
    // [6,2] + [1,5,3] = [6,2,1,5,3]-L3 => [6,5] = 9
    seededRandTest('drop low on aggregated dice', '(2d6+3d6)-L3', 11);

    test('missing clamp target', () {
      expect(
        () => DiceExpression.create('6d6 C<', seededRandom).roll(),
        throwsFormatException,
      );
    });
  });

  group('listeners', () {
    test('basic', () {
      final dice = DiceExpression.create('2d6 kh', seededRandom);
      final results = <RollResult>[];
      final summaries = <RollSummary>[];
      dice.roll(
        onRoll: (rr) {
          results.add(rr);
        },
        onSummary: (rs) {
          summaries.add(rs);
        },
      );
      const rrRoll = RollResult(
        expression: '(2d6)',
        opType: OpType.rollDice,
        nsides: 6,
        ndice: 2,
        results: [2, 6],
        metadata: RollMetadata(
          rolled: [2, 6],
        ),
      );
      const rrDrop = RollResult(
        expression: '((2d6) kh )',
        opType: OpType.drop,
        nsides: 6,
        ndice: 2,
        results: [6],
        metadata: RollMetadata(
          discarded: [2],
        ),
        left: rrRoll,
      );
      final expectedSummary = RollSummary(detailedResults: rrDrop);
      expect(
        results,
        equals([
          rrRoll,
          rrDrop,
        ]),
      );
      expect(
        summaries,
        equals([
          expectedSummary,
        ]),
      );
    });
  });

  group('addition combines', () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest(
      'addition combines results (drop is higher priority than plus)',
      '3d6+1d6-L1',
      9,
    );
    seededRandTest('addition combines results - parens', '(2d6+2d6)-L1', 13);
  });

  group('mult variations', () {
    // mocked responses should return rolls of 6, 2, 1, 5
    seededRandTest('int mult on rhs', '2d6*2', 16);
    seededRandTest('int mult on lhs', '2*2d6', 16);
    seededRandTest('int mult on lhs', '(2*2d6)-l', 0);
  });

  group('missing ints', () {
    seededRandTest('empty string returns zero', '', 0);
    seededRandTest('empty arith returns zero - add', '+', 0);
    seededRandTest('empty arith returns zero - mult', '*', 0);
    seededRandTest('empty ndice is 1', 'd6', 6);
    seededRandTest('whitespace should be swallowed', '2 d6', 8);
    seededRandTest('whitespace should be swallowed', '2d 6', 8);

    test('missing nsides', () {
      expect(
        () => DiceExpression.create('6d', seededRandom).roll(),
        throwsFormatException,
      );
    });
  });
  group('metadata', () {
    seededRandTest(
      'reroll, keep, count success,count fail, add',
      '(((10d6 r=3)kh2 #s>5)#f<2)+2',
      14,
      expectedResults: [6, 6, 2],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5, 3, 5, 1, 4, 6, 5, 6],
        discarded: [3, 6, 5, 5, 5, 4, 2, 1, 1],
        score: RollScore(
          successes: [6, 6],
        ),
      ),
    );

    seededRandTest(
      'score is determined from subtrees',
      '(4d6#s<=2#f>=5) + 1',
      15,
      expectedResults: [6, 2, 1, 5, 1],
      expectedMetadata: const RollMetadata(
        rolled: [6, 2, 1, 5],
        score: RollScore(
          // `+ 1` isn't included in success, since it's after parens
          successes: [2, 1],
          failures: [6, 5],
        ),
      ),
    );

    seededRandTest(
      'separate keeps',
      '(((4d6 kh3) + (4d6 kh2))kh3)',
      16,
      expectedResults: [6, 5, 5],
      expectedMetadata: const RollMetadata(
        rolled: [1, 2, 5, 6, 1, 3, 4, 5],
        discarded: [1, 3, 1, 4, 2],
      ),
    );
  });

  group('reroll', () {
    seededRandTest('reroll', '10d4 r=3', 35);
    seededRandTest('reroll', '10d4 r3', 35);
    seededRandTest('reroll', '10d4 r<2', 33);
    seededRandTest('reroll', '10d4 r>2', 16);
    seededRandTest('reroll', '10d4 r<=3', 40);
    seededRandTest('reroll', '10d4 r>=2', 10);

    seededRandTest('reroll', '10d4 ro=3', 35);
    seededRandTest('reroll', '10d4 ro3', 35);
    seededRandTest('reroll', '10d4 ro<2', 33);
    seededRandTest('reroll', '10d4 ro>2', 26);
    seededRandTest('reroll', '10d4 ro<=3', 34);
    seededRandTest('reroll', '10d4 ro>=2', 27);

    seededRandTest('reroll once', '8d6r>3', 15);
    seededRandTest('reroll once', '8d6ro>3', 28);
  });

  group('dice', () {
    staticRandTest('order of operations, with dice', '5 + 6 * 2d6', 29);

    seededRandTest('simple roll', '1d6', 6);
    seededRandTest('simple roll', 'd6', 6);
    seededRandTest('percentile', '1d%', 96);
    seededRandTest('percentile', 'd%', 96);
    seededRandTest('D66', '1D66', 62);
    seededRandTest('D66', 'D66', 62);
    seededRandTest('d66 -- 66-sided, not D66', '1d66', 30);
    seededRandTest('d66 -- 66-sided, not D66', 'd66', 30);
    seededRandTest('ndice in parens', '(4+6)d10', 54);
    seededRandTest('nsides in parens', '10d(2*3)', 38);

    seededRandTest('zero dice rolled', '0d6', 0);

    staticRandTest('dice expr as sides', '2d(3d6)', 4);

    seededRandTest('fudge', '4dF', 0);
    seededRandTest('fudge', 'dF', 1);
    seededRandTest('fudge', '1dF', 1);

    // 1st roll: 6, 2, 1, 5, 3, 5, 1, 4, 6, (explodes 2) (total 33)
    // 2nd roll: 5,6 (explodes 1) (total 11)
    // 3rd roll: 4 (explodes 0) (total 4)
    seededRandTest('exploding dice', '9d6!', 48);
    seededRandTest('exploding dice', '9d6!6', 48);
    seededRandTest('exploding dice', '9d6!=6', 48);
    seededRandTest('exploding dice', '9d6!>=6', 48);
    seededRandTest('exploding dice', '9d6!>5', 48);

    seededRandTest('exploding dice', '9d6!o', 44);
    seededRandTest('exploding dice', '9d6!o6', 44);
    seededRandTest('exploding dice', '9d6!o=6', 44);
    seededRandTest('exploding dice', '9d6!o>=6', 44);
    seededRandTest('exploding dice', '9d6!o>5', 44);

    seededRandTest('exploding dice', '9d6!1', 44);
    seededRandTest('exploding dice', '9d6!>=5', 56);
    seededRandTest('exploding dice', '9d6!<2', 44);
    seededRandTest('exploding dice', '9d6!<=3', 54);

    seededRandTest('exploding dice', '9d6!o1', 44);
    seededRandTest('exploding dice', '9d6!o>=5', 50);
    seededRandTest('exploding dice', '9d6!o<2', 44);
    seededRandTest('exploding dice', '9d6!o<=3', 50);

    // 1st round: 6, 2, 1, 5, 3, 5, 1, 4, 6, (compounds 2) (total 33)
    // 2nd round: 5,                      6 (compounds 1) (total 11)
    // 3rd round:                         4 (compounds 0) (total 4)
    // result    11, 2, 1, 5, 3, 5, 1, 4, 16
    seededRandTest('compounding dice', '9d6!!', 48);
    seededRandTest('compounding dice', '9d6!!6', 48);
    seededRandTest('compounding dice', '9d6!!=6', 48);
    seededRandTest('compounding dice', '9d6!!>=6', 48);
    seededRandTest('compounding dice', '9d6!!>5', 48);

    seededRandTest('compounding dice', '9d6!!o', 44);
    seededRandTest('compounding dice', '9d6!!o6', 44);
    seededRandTest('compounding dice', '9d6!!o=6', 44);
    seededRandTest('compounding dice', '9d6!!o>=6', 44);
    seededRandTest('compounding dice', '9d6!!o>5', 44);

    seededRandTest('compounding dice count', '9d6!!#>6', 2);

    seededRandTest('compounding dice', '9d6!!>=5', 56);
    seededRandTest('compounding dice', '9d6!!<3', 48);
    seededRandTest('compounding dice', '9d6!!<=3', 54);
    seededRandTest('compounding dice', '9d6!!1', 44);

    seededRandTest('compounding dice', '9d6!!o>=5', 50);
    seededRandTest('compounding dice', '9d6!!o<3', 48);
    seededRandTest('compounding dice', '9d6!!o<=3', 50);
    seededRandTest('compounding dice', '9d6!!o1', 44);

    seededRandTest('explode arith result', '(9d6+3)!', 51);

    // explode, then count 6's
    seededRandTest('exploding dice and count', '9d6!#=6', 3);
    // explode, then drop less-than-6, then count (should be identical to above)
    seededRandTest('exploding dice and count variation', '9d6!-<6#', 3);

    // different dice pools can be combined
    seededRandTest('differing nsides addition', '4d4 + 4d6', 25);
    // fudge dice can be rolled
    seededRandTest('differing nsides addition', '4dF + 6dF', 2);
    // fudge dice can be added to [1, -1, -1, 1]
    seededRandTest('differing nsides addition', '4dF + 1', 1);
    seededRandTest(
      'fudge add to d6',
      '4d6+4dF',
      14,
    );
    seededRandTest('fudge add to d6', '4dF+4d6', 13);

    test('multiple rolls is multiple results', () {
      final dice = DiceExpression.create('2d6', seededRandom);
      expect(dice.roll().total, 8);
      expect(dice.roll().total, 6);
    });

    test('create dice with real random', () {
      final dice = DiceExpression.create('10d100');
      final result1 = dice.roll();
      // result will never be zero -- this test is verifying creating the expr & doing roll
      expect(result1, isNot(0));
    });

    test('string method returns expr', () {
      final dice = DiceExpression.create('2d6# + 5d6!>=5 + 5D66', seededRandom);
      expect(dice.toString(), '((2d6) # (( + ((5d6) !>= 5)) + (5D66)))');
    });

    test('invalid dice str', () {
      expect(
        () => DiceExpression.create('1d5 + x2', seededRandom).roll(),
        throwsFormatException,
      );
    });
    final invalids = [
      '4!',
      '4dF!',
      '4dF!!',
      '4dFr',
      '4D66!',
      '4D66!!',
      '4D66 r',
    ];
    for (final i in invalids) {
      test('invalid - $i', () {
        expect(
          () => DiceExpression.create(i, seededRandom).roll(),
          throwsFormatException,
        );
      });
    }

    test('toString', () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create(
        '(4d(3+3)!  + (2+2)d6) #cs #cf #s #f',
        seededRandom,
      );
      final out = dice.roll().toString();
      expect(
        out,
        equals(
          '(((((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) #cf ) #s ) #f ) ===> RollSummary(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {rolled: [6, 2, 1, 5, 3, 5, 1, 4, 6], score: {successes: [6, 6], failures: [1, 1], critSuccesses: [6, 6], critFailures: [1, 1]}})',
        ),
      );
    });
    test('toStringPretty', () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create(
        '(4d(3+3)!  + (2+2)d6) #cs #cf #s #f',
        seededRandom,
      );
      final out = dice.roll().toStringPretty();
      expect(
        out,
        equals(
          '''
(((((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) #cf ) #s ) #f ) ===> RollSummary(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {rolled: [6, 2, 1, 5, 3, 5, 1, 4, 6], score: {successes: [6, 6], failures: [1, 1], critSuccesses: [6, 6], critFailures: [1, 1]}})
  (((((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) #cf ) #s ) #f ) =count=> RollResult(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {score: {failures: [1, 1]}})
      ((((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) #cf ) #s ) =count=> RollResult(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {score: {successes: [6, 6]}})
          (((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) #cf ) =count=> RollResult(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {score: {critFailures: [1, 1]}})
              ((((4d(3 + 3)) ! ) + ((2 + 2)d6)) #cs ) =count=> RollResult(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6], metadata: {score: {critSuccesses: [6, 6]}})
                  (((4d(3 + 3)) ! ) + ((2 + 2)d6)) =add=> RollResult(total: 33, results: [6, 2, 1, 5, 3, 5, 1, 4, 6])
                      ((4d(3 + 3)) ! ) =explode=> RollResult(total: 17, results: [6, 2, 1, 5, 3], metadata: {rolled: [3]})
                          (4d(3 + 3)) =rollDice=> RollResult(total: 14, results: [6, 2, 1, 5], metadata: {rolled: [6, 2, 1, 5]})
                              (3 + 3) =add=> RollResult(total: 6, results: [3, 3])
                      ((2 + 2)d6) =rollDice=> RollResult(total: 16, results: [5, 1, 4, 6], metadata: {rolled: [5, 1, 4, 6]})
                          (2 + 2) =add=> RollResult(total: 4, results: [2, 2])
        '''
              .trim(),
        ),
      );
    });
    test('toJson', () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('4d6', seededRandom);
      final obj = dice.roll().toJson();
      expect(
        obj,
        equals({
          'expression': '(4d6)',
          'total': 14,
          'results': [6, 2, 1, 5],
          'detailedResults': {
            'expression': '(4d6)',
            'opType': 'rollDice',
            'nsides': 6,
            'ndice': 4,
            'results': [6, 2, 1, 5],
            'metadata': {
              'rolled': [6, 2, 1, 5],
            },
          },
          'metadata': {
            'rolled': [6, 2, 1, 5],
          },
        }),
      );
    });

    test('toJson - metadata', () {
      // mocked responses should return rolls of 6, 2, 1, 5
      final dice = DiceExpression.create('4d6 #cf #cs', seededRandom);
      final obj = dice.roll().toJson();
      expect(
        obj,
        equals(
          {
            'expression': '(((4d6) #cf ) #cs )',
            'total': 14,
            'results': [6, 2, 1, 5],
            'detailedResults': {
              'expression': '(((4d6) #cf ) #cs )',
              'opType': 'count',
              'nsides': 6,
              'ndice': 4,
              'results': [6, 2, 1, 5],
              'metadata': {
                'score': {
                  'critSuccesses': [6],
                },
              },
              'left': {
                'expression': '((4d6) #cf )',
                'opType': 'count',
                'nsides': 6,
                'ndice': 4,
                'results': [6, 2, 1, 5],
                'metadata': {
                  'score': {
                    'critFailures': [1],
                  },
                },
                'left': {
                  'expression': '(4d6)',
                  'opType': 'rollDice',
                  'nsides': 6,
                  'ndice': 4,
                  'results': [6, 2, 1, 5],
                  'metadata': {
                    'rolled': [6, 2, 1, 5],
                  },
                },
              },
            },
            'metadata': {
              'rolled': [6, 2, 1, 5],
              'score': {
                'critSuccesses': [6],
                'critFailures': [1],
              },
            },
          },
        ),
      );
    });

    test('rollN test', () async {
      final dice = DiceExpression.create('2d6', seededRandom);

      final results =
          await dice.rollN(2).map((result) => result.total).toList();
      // mocked responses should return rolls of 6, 2, 1, 5
      expect(results, equals([8, 6]));
    });

    test('stats test', () async {
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
