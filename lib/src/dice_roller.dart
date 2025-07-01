import 'dart:math';

import 'results.dart';
import 'utils.dart';

/// Abstract dice roller interface.
abstract class DiceRoller with LoggingMixin {
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

  /// simultaneous rolls flag (impacts Futures queuing)
  bool simultaneousRolls = false;

  /// Roll ndice of nsides and return results as list.
  Future<RollResult> roll(int ndice, int nsides, [String msg = '']);

  /// Roll N fudge dice, return results
  Future<RollResult> rollFudge(int ndice);

  /// Roll N dice with custom side values, return results
  Future<RollResult> rollVals(int ndice, List<int> sideVals);
}

/// Default implementation of DiceRoller.
class DefaultDiceRoller extends DiceRoller {
  /// Constructs a dice roller
  DefaultDiceRoller([Random? r, bool simultaneousRolls = false])
      : _random = r ?? Random.secure() {
    this.simultaneousRolls = simultaneousRolls;
  }

  final Random _random;

  /// select n items from the list of values
  List<T> selectN<T>(int n, List<T> vals) => [
        for (var i = 0; i < n; i++) vals[_random.nextInt(vals.length)],
      ];

  @override
  Future<RollResult> roll(int ndice, int nsides, [String msg = '']) async {
    RangeError.checkValueInInterval(
        ndice, DiceRoller.minDice, DiceRoller.maxDice, 'ndice');
    RangeError.checkValueInInterval(
        nsides, DiceRoller.minSides, DiceRoller.maxSides, 'nsides');
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

  @override
  Future<RollResult> rollFudge(int ndice) async {
    RangeError.checkValueInInterval(
        ndice, DiceRoller.minDice, DiceRoller.maxDice, 'ndice');
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

  @override
  Future<RollResult> rollVals(int ndice, List<int> sideVals) async {
    RangeError.checkValueInInterval(
        ndice, DiceRoller.minDice, DiceRoller.maxDice, 'ndice');
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
