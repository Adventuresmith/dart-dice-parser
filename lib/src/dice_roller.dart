import 'dart:math';

import 'package:logging/logging.dart';

/// A dice roller for M dice of N sides (e.g. `2d6`).
/// A roll returns a list of ints
/// Also handles fudge die, and exploding die.
class DiceRoller {
  final Logger _log = Logger("DiceRoller");
  final Random _random;

  /// minimum dice to roll (0)
  static const int minDice = 0;

  /// maximum dice to allow to be rolled (10k)
  static const int maxDice = 10000;

  /// minimum sides of dice (1)
  static const int minSides = 1;

  /// maximum sides of dice (1k)
  static const int maxSides = 1000;

  /// default limit to # of times dice rolls can explode (1k)
  static const int defaultExplodeLimit = 100;

  /// Constructs a dice roller (Random can be injected)
  DiceRoller([Random? r]) : _random = r ?? Random.secure();

  /// Roll ndice of nsides and return results as list.
  List<int> roll(int ndice, int nsides) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    RangeError.checkValueInInterval(nsides, minSides, maxSides, 'nsides');
    // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    final results = [
      for (int i = 0; i < ndice; i++) _random.nextInt(nsides) + 1
    ];
    _log.finest(() => "roll ${ndice}d$nsides => $results");
    return results;
  }

  /// return result of rolling given number of nsided dice.
  List<int> rollWithExplode({
    required int ndice,
    required int nsides,
    bool explode = false,
    int explodeLimit = defaultExplodeLimit,
  }) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    RangeError.checkValueInInterval(nsides, minSides, maxSides, 'nsides');

    final results = <int>[];
    var numToRoll = ndice;

    var explodeCount = 0;
    while (numToRoll > 0 && explodeCount <= explodeLimit) {
      if (explodeCount > 0) {
        _log.finest(() => "explode $numToRoll !");
      }
      final localResults = roll(numToRoll, nsides);
      results.addAll(localResults);
      if (!explode) {
        break;
      }
      if (nsides == 1) {
        _log.finer("1-sided dice cannot explode");
        break;
      }

      explodeCount++;
      numToRoll = localResults.where((v) => v == nsides).length;
    }

    _log.finest(() => "roll ${ndice}d!$nsides => $results");
    return results;
  }

  static const _fudgeVals = [-1, -1, 0, 0, 1, 1];

  /// Roll N fudge dice, return results
  List<int> rollFudge(int ndice) {
    RangeError.checkValueInInterval(ndice, minDice, maxDice, 'ndice');
    final results = [
      for (var i = 0; i < ndice; i++)
        _fudgeVals[_random.nextInt(_fudgeVals.length)]
    ];
    _log.finest(() => "roll ${ndice}dF => $results");
    return results;
  }
}
