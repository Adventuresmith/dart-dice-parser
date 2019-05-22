import 'dart:math';

///
class DiceRoller {
  Random random;

  DiceRoller([Random r]) {
    random = r ?? new Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  DiceRollResult roll(int ndice, int nsides) {
    var rolls = <int>[];
    for (int i = 0; i < ndice; i++) {
      rolls.add(random.nextInt(nsides) + 1); // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    }
    return new DiceRollResult(rolls);
  }

  static const _fudgeVals = const [-1, -1, 0, 0, 1, 1];

  // fudge dice roll
  DiceRollResult rollFudge(int ndice) {
    var rolls = <int>[];
    for (int i = 0; i < ndice; i++) {
      rolls.add(_fudgeVals[random.nextInt(_fudgeVals.length)]);
    }
    return new DiceRollResult(rolls);
  }
}

class DiceRollResult {
  final List<int> rolls;

  DiceRollResult(this.rolls);

  int total() {
    return rolls.reduce((a, b) => a + b);
  }
}
