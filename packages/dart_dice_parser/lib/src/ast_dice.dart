import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:petitparser/parser.dart';

import 'ast_core.dart';
import 'dice_roller.dart';
import 'enums.dart';
import 'roll_result.dart';
import 'rolled_die.dart';

/// roll fudge dice
class FudgeDice extends UnaryDice {
  FudgeDice(super.name, super.left, super.roller);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final ndice = lhs.totalOrDefault(() => 1);

    // redundant w/ RangeError checks in the DiceRoller. But we can construct better error messages here.
    if (ndice < DiceRoller.minDice || ndice > DiceRoller.maxDice) {
      throw FormatException(
        'Invalid number of dice ($ndice)',
        toString(),
        left.toString().length,
      );
    }
    final roll = await roller.rollFudge(ndice);
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
  Future<RollResult> eval() async {
    final lhs = await left();
    final ndice = lhs.totalOrDefault(() => 1);

    final roll = await roller.rollVals(
      ndice,
      IList(vals.elements.map(int.parse)),
    );

    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: OpType.rollVals,
      left: lhs,
    );
  }
}

class PenetratingDice extends UnaryDice {
  PenetratingDice(
    super.op,
    super.left,
    super.roller, {
    required String nsides,
    required String nsidesPenetration,
  }) : nsides = int.parse(nsides),
       nsidesPenetration = nsidesPenetration.isEmpty
           ? int.parse(nsides)
           : int.parse(nsidesPenetration);

  final int nsides;
  final int nsidesPenetration;
  final limit = DiceRoller.defaultRerollLimit;

  @override
  String toString() => '(${left}d${nsides}p$nsidesPenetration)';

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final ndice = lhs.totalOrDefault(() => 1);

    final roll = await roller.roll(ndice, nsides);

    final results = <RolledDie>[];
    final discarded = <RolledDie>[];
    for (final (index, rolledDie) in roll.results.indexed) {
      if (rolledDie.isMaxResult) {
        var sum = rolledDie.result;
        RolledDie rerolled;
        var numPenetrated = 0;
        discarded.add(
          RolledDie.copyWith(rolledDie, discarded: true, penetrator: true),
        );
        do {
          rerolled = (await roller.roll(
            1,
            nsidesPenetration,
            '(penetration ind[$index] #${numPenetrated + 1})',
          )).results.first;
          discarded.add(
            RolledDie.copyWith(rerolled, discarded: true, penetrator: true),
          );
          sum += rerolled.result;
          numPenetrated++;
        } while (rerolled.isMaxResult && numPenetrated < limit);
        discarded.add(
          RolledDie.singleVal(
            result: -numPenetrated,
            discarded: true,
            penetrator: true,
          ),
        );
        results.add(
          RolledDie.copyWith(
            rolledDie,
            result: sum - numPenetrated,
            penetrated: true,
            from: discarded,
          ),
        );
      } else {
        results.add(rolledDie);
      }
    }

    return RollResult(
      expression: toString(),
      opType: OpType.rollPenetration,
      results: results,
      discarded: lhs.discarded + discarded,
      left: lhs,
    );
  }
}

/// roll n % dice
class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final ndice = lhs.totalOrDefault(() => 1);
    final roll = await roller.roll(ndice, 100);
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
  Future<RollResult> eval() async {
    final lhs = await left();
    final ndice = lhs.totalOrDefault(() => 1);
    final roll = await roller.rollD66(ndice);
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
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();
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
    final roll = await roller.roll(ndice, nsides);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: roll.opType,
      left: lhs,
      right: rhs,
    );
  }
}
