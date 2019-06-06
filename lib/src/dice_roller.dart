import 'dart:math';

import 'package:logging/logging.dart';

/// A dice roller for M dice of N sides
class DiceRoller {
  final Logger log = Logger("DiceRoller");
  Random _random;

  /// Constructs a dice roller (Random can be injected)
  DiceRoller([Random r]) {
    _random = r ?? Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  List<int> roll(int ndice, int nsides) {
    // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    var results = [for (int i = 0; i < ndice; i++) _random.nextInt(nsides) + 1];
    log.finest(() => "roll ${ndice}d$nsides => $results");
    return results;
  }

  static const _fudgeVals = [-1, -1, 0, 0, 1, 1];

  /// Roll N fudge dice, return results
  List<int> rollFudge(int ndice) {
    var results = [
      for (var i = 0; i < ndice; i++)
        _fudgeVals[_random.nextInt(_fudgeVals.length)]
    ];
    log.finest(() => "roll ${ndice}dF => $results");
    return results;
  }
}
