import 'dart:math';

import 'results.dart';
import 'utils.dart';

/// A dice roller for M dice of N sides (e.g. `2d6`).
/// A roll returns a list of ints.
class DiceRoller with LoggingMixin {
  /// Constructs a dice roller
  DiceRoller([Random? r]) : _random = r ?? Random.secure();

  final Random _random;

  /// minimum dice to roll (0)
  static const int minDice = 0;

  /// maximum dice to allow to be rolled (1k)
  static const int maxDice = 1000;

  /// minimum sides of dice (2)
  static const int minSides = 2;

  /// maximum sides of dice (100k)
  static const int maxSides = 100000;

  /// default limit to # of times dice rolls can explode (100)
  static const int defaultExplodeLimit = 100;

  /// Roll ndice of nsides and return results as list.
  RollResult roll(int ndice, int nsides, [String msg = '']) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    RangeError.checkValueInInterval(nsides, minSides, maxSides, 'nsides');
    // nextInt is zero-inclusive; add 1 so result will be in range 1-nsides
    final results = [
      for (int i = 0; i < ndice; i++) _random.nextInt(nsides) + 1,
    ];
    logger.finest(() => 'roll ${ndice}d$nsides => $results $msg');
    return RollResult(
      expression: '${ndice}d$nsides',
      opType: OpType.rollDice,
      metadata: RollMetadata(rolled: results),
      ndice: ndice,
      nsides: nsides,
      results: results,
    );
  }

  static const _fudgeVals = [-1, -1, 0, 0, 1, 1];

  /// select n items from the list of values
  List<T> selectN<T>(int n, List<T> vals) => [
        for (var i = 0; i < n; i++) vals[_random.nextInt(vals.length)],
      ];

  /// Roll N fudge dice, return results
  RollResult rollFudge(int ndice) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    final results = selectN(ndice, _fudgeVals);

    logger.finest(() => 'roll ${ndice}dF => $results');

    return RollResult(
      expression: '${ndice}dF',
      opType: OpType.rollFudge,
      metadata: RollMetadata(rolled: results),
      ndice: ndice,
      results: results,
    );
  }

  /// Roll N fudge dice, return results
  RollResult rollVals(int ndice, List<int> sideVals) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    final results = selectN(ndice, sideVals);

    logger.finest(() => 'roll ${ndice}d$sideVals => $results');

    return RollResult(
      expression: '${ndice}d$sideVals',
      opType: OpType.rollVals,
      metadata: RollMetadata(rolled: results),
      ndice: ndice,
      results: results,
    );
  }
}
