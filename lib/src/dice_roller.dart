import 'dart:math';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'enums.dart';
import 'roll_result.dart';
import 'rolled_die.dart';
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

  RollResult reroll(RolledDie rolledDie, [String msg = '']) {
    switch (rolledDie.dieType) {
      case DieType.polyhedral:
        return roll(1, rolledDie.nsides, msg);
      case DieType.fudge:
        return rollFudge(1, msg);
      case DieType.d66:
        return rollD66(1, msg);
      case DieType.nvals:
        return rollVals(1, rolledDie.potentialValues, msg);
      default:
        return RollResult(
          expression: rolledDie.result.toString(),
          opType: OpType.value,
          results: [RolledDie.singleVal(result: rolledDie.result)],
        );
    }
  }

  RollResult rollD66(int ndice, [String msg = '']) {
    final results = <RolledDie>[];
    final discarded = <RolledDie>[];
    for (var i = 0; i < ndice; i++) {
      final tensRoll = roll(1, 6, 'D66*10 $msg');
      final onesRoll = roll(1, 6, 'D66*1 $msg');
      final total = tensRoll.total * 10 + onesRoll.total;
      final rolled = [
        RolledDie.discard(tensRoll.results.first),
        RolledDie.discard(onesRoll.results.first),
      ];
      discarded.addAll(rolled);
      results.add(RolledDie.d66(result: total, from: rolled));
    }
    logger.finest(
      () => 'roll ${ndice}D66 => $results {discarded: $discarded} $msg',
    );
    return RollResult(
      expression: toString(),
      opType: OpType.rollD66,
      results: results,
      discarded: discarded,
    );
  }

  /// Roll ndice of nsides and return results
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
      results: [
        ...results.map((i) => RolledDie.polyhedral(result: i, nsides: nsides)),
      ],
    );
  }

  /// select n items from the list of values
  Iterable<T> selectN<T>(int n, IList<T> vals) => [
    for (var i = 0; i < n; i++) vals[_random.nextInt(vals.length)],
  ];

  /// Roll N fudge dice, return results
  RollResult rollFudge(int ndice, [String msg = '']) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    final results = selectN(ndice, RolledDie.defaultFudgeVals);

    logger.finest(() => 'roll ${ndice}dF => $results $msg');

    return RollResult(
      expression: '${ndice}dF',
      opType: OpType.rollFudge,
      results: [...results.map((i) => RolledDie.fudge(result: i))],
    );
  }

  /// Roll N fudge dice, return results
  RollResult rollVals(int ndice, IList<int> sideVals, [String msg = '']) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    final results = selectN(ndice, sideVals);

    logger.finest(
      () => 'roll ${ndice}d${sideVals.toString(false)} => $results $msg',
    );

    return RollResult(
      expression: '${ndice}d$sideVals',
      opType: OpType.rollVals,
      results: [
        ...results.map(
          (i) => RolledDie(
            result: i,
            nsides: sideVals.length,
            dieType: DieType.nvals,
            potentialValues: sideVals,
          ),
        ),
      ],
    );
  }
}
