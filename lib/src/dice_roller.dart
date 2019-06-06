import 'dart:math';

/// A dice roller for M dice of N sides
class DiceRoller {
  Random _random;

  /// Constructs a dice roller (Random can be injected)
  DiceRoller([Random r]) {
    _random = r ?? Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  List<int> roll(int ndice, int nsides) {
    // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    return [for (int i = 0; i < ndice; i++) _random.nextInt(nsides) + 1];
  }

  static const _fudgeVals = [-1, -1, 0, 0, 1, 1];

  /// Roll N fudge dice, return results
  List<int> rollFudge(int ndice) {
    return [
      for (var i = 0; i < ndice; i++)
        _fudgeVals[_random.nextInt(_fudgeVals.length)]
    ];
  }
}

/// sum an Iterable of integers
int sum(Iterable<int> l) => l.reduce((a, b) => a + b);
