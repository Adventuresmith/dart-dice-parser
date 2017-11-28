
import 'dart:math';

///
class DiceRoller {
  Random random;

  DiceRoller([Random r]) {
    random = r ?? new Random.secure();
  }

  /// return result of rolling given number of nsided dice.
  int roll(int ndice, int nsides) {
    var sum = 0;
    for (int i = 0; i < ndice; i++) {
      sum += random.nextInt(nsides) + 1; // nextInt is zero-inclusive, add 1 so it starts at 1 like dice
    }
    return sum;
  }

  static const _fudgeVals = const [
    -1, -1,
    0, 0,
    1, 1
  ];

  // fudge dice roll
  int rollFudge(int ndice) {
    var sum = 0;
    for (int i = 0; i < ndice; i++) {
      sum += _fudgeVals[random.nextInt(_fudgeVals.length)];
    }
    return sum;
  }
}