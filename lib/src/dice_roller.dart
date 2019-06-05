import 'dart:math';

/// A dice roller for M dice of N sides
class DiceRoller {
  Random random;

  DiceRoller([Random r]) {
    random = r ?? new Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  DiceRollResult roll(int ndice, int nsides) {
    // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    return new DiceRollResult(
        [for (int i = 0; i < ndice; i++) random.nextInt(nsides) + 1]);
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
  DiceRollResult roll(int ndice) {
    return new DiceRollResult([
      for (var i = 0; i < ndice; i++)
        _fudgeVals[random.nextInt(_fudgeVals.length)]
    ]);
  }
}

/// Results of dice roles
class DiceRollResult {
  final List<int> rolls;

  DiceRollResult(this.rolls);

  int total() {
    return rolls.reduce((a, b) => a + b);
  }
}
