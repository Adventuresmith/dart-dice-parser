import 'dart:math';

/// A dice roller for M dice of N sides
class DiceRoller {
  Random random;

  DiceRoller([Random r]) {
    random = r ?? new Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  List<int> roll(int ndice, int nsides) {
    // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    return [for (int i = 0; i < ndice; i++) random.nextInt(nsides) + 1];
  }
}

/// A dice roller for fudge dice (values -1,0,1)
class FudgeDiceRoller {
  static const _fudgeVals = const [-1, -1, 0, 0, 1, 1];
  Random random;

  FudgeDiceRoller([Random r]) {
    random = r ?? new Random.secure();
  }

  /// Roll N fudge dice, return results
  List<int> roll(int ndice) {
    return [
      for (var i = 0; i < ndice; i++)
        _fudgeVals[random.nextInt(_fudgeVals.length)]
    ];
  }
}

int sum(Iterable<int> l) => l.reduce((a, b) => a + b);
