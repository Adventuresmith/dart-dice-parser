import 'dart:math';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'enums.dart';
import 'roll_result.dart';
import 'rolled_die.dart';
import 'utils.dart';

abstract class DiceRoller {
  /// minimum dice to roll (0)
  static const minDice = 0;

  /// maximum dice to allow to be rolled (1k)
  static const maxDice = 1000;

  /// minimum sides of dice (2)
  static const minSides = 2;

  /// maximum sides of dice (100k)
  static const maxSides = 100000;

  /// default limit for rerolls/exploding/compounding to avoid getting stuck in loop
  static const defaultRerollLimit = 1000;

  /// return an Stream of ints. length == ndice, range: [min,nsides]
  /// duplicates allowed.
  Stream<int> roll({required int ndice, required int nsides, int min = 1});

  /// return an Stream of ints selected from the given vals. length = ndice.
  /// results should be selected at random from vals.
  /// duplicates allowed.
  Stream<int> rollVals(int ndice, List<int> vals);
}

/// a dice roller that uses an RNG
class RNGRoller extends DiceRoller {
  RNGRoller([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  /// select n items from the list of values. duplicates are possible
  Iterable<int> selectNFromVals<int>(num ndice, List<int> vals) => [
    for (var i = 0; i < ndice; i++) vals[_random.nextInt(vals.length)],
  ];

  Iterable<int> selectN({
    required int ndice,
    required int nsides,
    int min = 1,
  }) => [for (int i = 0; i < ndice; i++) _random.nextInt(nsides) + min];

  @override
  Stream<int> roll({
    required int ndice,
    required int nsides,
    int min = 1,
  }) async* {
    RangeError.checkValueInInterval(
      ndice,
      DiceRoller.minDice,
      DiceRoller.maxDice,
      'ndice',
    );
    RangeError.checkValueInInterval(
      nsides,
      DiceRoller.minSides,
      DiceRoller.maxSides,
      'nsides',
    );
    for (final i in selectN(ndice: ndice, nsides: nsides, min: min)) {
      yield i;
    }
  }

  @override
  Stream<int> rollVals(int ndice, List<int> vals) async* {
    RangeError.checkValueInInterval(
      ndice,
      DiceRoller.minDice,
      DiceRoller.maxDice,
      'ndice',
    );
    for (final i in selectNFromVals(ndice, vals)) {
      yield i;
    }
  }
}

/// A dice roller for standard polyhedral dice, fudge dice, etc.
class DiceResultRoller with LoggingMixin {
  /// Constructs a dice roller
  DiceResultRoller([DiceRoller? r])
    : _diceRoller = r ?? RNGRoller(Random.secure());

  final DiceRoller _diceRoller;

  Future<RollResult> reroll(RolledDie rolledDie, [String msg = '']) async {
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

  Future<RollResult> rollD66(int ndice, [String msg = '']) async {
    final results = <RolledDie>[];
    final discarded = <RolledDie>[];
    for (var i = 0; i < ndice; i++) {
      final digits = await _diceRoller.roll(ndice: 2, nsides: 6).toList();
      logger.finest(() => 'roll ${ndice}D66 => $digits $msg');
      final tens = digits[0];
      final ones = digits[1];
      final total = tens * 10 + ones;
      final rolled = [
        ...digits.map(
          (i) => RolledDie.polyhedral(result: i, nsides: 6, discarded: true),
        ),
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
  Future<RollResult> roll(int ndice, int nsides, [String msg = '']) async {
    // nextInt is zero-inclusive; add 1 so result will be in range 1-nsides
    final results = await _diceRoller
        .roll(ndice: ndice, nsides: nsides)
        .toList();
    logger.finest(() => 'roll ${ndice}d$nsides => $results $msg');
    return RollResult(
      expression: '${ndice}d$nsides',
      opType: OpType.rollDice,
      results: [
        ...results.map((i) => RolledDie.polyhedral(result: i, nsides: nsides)),
      ],
    );
  }

  /// Roll N fudge dice, return results
  Future<RollResult> rollFudge(int ndice, [String msg = '']) async {
    final results = await _diceRoller
        .rollVals(ndice, RolledDie.defaultFudgeVals)
        .toList();

    logger.finest(() => 'roll ${ndice}dF => $results $msg');

    return RollResult(
      expression: '${ndice}dF',
      opType: OpType.rollFudge,
      results: [...results.map((i) => RolledDie.fudge(result: i))],
    );
  }

  /// Roll N fudge dice, return results
  Future<RollResult> rollVals(
    int ndice,
    IList<int> sideVals, [
    String msg = '',
  ]) async {
    final results = await _diceRoller
        .rollVals(ndice, sideVals.toList(growable: false))
        .toList();

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
