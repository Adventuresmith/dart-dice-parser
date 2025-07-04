import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:petitparser/parser.dart';

import 'ast_core.dart';
import 'dice_roller.dart';
import 'results.dart';

/// roll fudge dice
class FudgeDice extends UnaryDice {
  FudgeDice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final lhs = left();
    final ndice = lhs.totalOrDefault(() => 1);

    // redundant w/ RangeError checks in the DiceRoller. But we can construct better error messages here.
    if (ndice < DiceRoller.minDice || ndice > DiceRoller.maxDice) {
      throw FormatException(
        'Invalid number of dice ($ndice)',
        toString(),
        left.toString().length,
      );
    }
    final roll = roller.rollFudge(ndice);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: roll.opType,
      left: lhs,
    );
  }
}

class CSVDice extends UnaryDice {
  CSVDice(super.op, super.left, super.roller, this.vals);

  final SeparatedList<String, String> vals;

  @override
  String toString() => '(${left}d${vals.elements})';

  @override
  RollResult eval() {
    final lhs = left();
    final ndice = lhs.totalOrDefault(() => 1);

    final roll = roller.rollVals(ndice, IList(vals.elements.map(int.parse)));

    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: OpType.rollVals,
      left: lhs,
    );
  }
}

/// roll n % dice
class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final lhs = left();
    final ndice = lhs.totalOrDefault(() => 1);
    final roll = roller.roll(ndice, 100);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: OpType.rollPercent,
      left: lhs,
    );
  }
}

/// roll n D66
class D66Dice extends UnaryDice {
  D66Dice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final lhs = left();
    final ndice = lhs.totalOrDefault(() => 1);
    final roll = roller.rollD66(ndice);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: OpType.rollD66,
      left: lhs,
    );
  }
}

/// roll N dice of Y sides.
class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  String toString() => '($left$name$right)';

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    final ndice = lhs.totalOrDefault(() => 1);
    final nsides = rhs.totalOrDefault(() => 1);

    // redundant w/ RangeError checks in the DiceRoller. But we can construct better error messages here.
    if (ndice < DiceRoller.minDice || ndice > DiceRoller.maxDice) {
      throw FormatException(
        'Invalid number of dice ($ndice)',
        toString(),
        left.toString().length,
      );
    }
    if (nsides < DiceRoller.minSides || nsides > DiceRoller.maxSides) {
      throw FormatException(
        'Invalid number of sides ($nsides)',
        toString(),
        left.toString().length + name.length + 1,
      );
    }
    final roll = roller.roll(ndice, nsides);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: roll.opType,
      left: lhs,
      right: rhs,
    );
  }
}
