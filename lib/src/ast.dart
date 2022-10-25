import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/dice_expression.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/results.dart';
import 'package:dart_dice_parser/src/utils.dart';

/// A value expression. The token we read from input will be a String,
/// it must parse as an int, and an empty string will return empty set.
class Value extends DiceExpression {
  Value(this.value)
      : _results = RollResult(
          name: value,
          value: value.isEmpty ? 0 : int.parse(value),
        );

  final String value;
  final RollResult _results;

  @override
  RollResult call() => _results;

  @override
  String toString() => value;
}

/// All our operations will inherit from this class.
abstract class DiceOp extends DiceExpression with LoggingMixin {
  /// each child class should override this to implement their operation
  RollResult eval();

  /// all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  RollResult call() {
    final results = eval();
    logger.finer(() => "$this => $results");
    return results;
  }
}

/// base class for unary operations
abstract class Unary extends DiceOp {
  Unary(this.name, this.left);
  final String name;
  final DiceExpression left;

  @override
  String toString() => '($left)$name';
}

/// base class for binary operations
abstract class Binary extends DiceOp {
  Binary(this.name, this.left, this.right);
  final String name;
  final DiceExpression left;
  final DiceExpression right;

  @override
  String toString() => '($left$name$right)';
}

/// multiply operation (flattens results)
class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = resolveToInt(left);
    final rhs = resolveToInt(right);
    return RollResult(
      name: name,
      value: lhs * rhs,
    );
  }
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    return left() + right();
  }
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = resolveToInt(left);
    final rhs = resolveToInt(right);
    return RollResult(
      name: name,
      value: lhs - rhs,
    );
  }
}

/// variation on count -- count how many results from lhs are =,<,> rhs.
class CountOp extends Binary {
  CountOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    List<int> rolls;
    if (lhs is DiceRollResult) {
      rolls = lhs.rolls;
    } else if (lhs is FudgeRollResult) {
      rolls = lhs.rolls;
    } else {
      throw ArgumentError(
        "Invalid operation ($left)$name -- cannot count arithmetic result",
      );
    }
    final target = resolveToInt(right, defaultVal: -1);
    if (target == -1 && name != '#') {
      // everything needs lhs except for
      throw FormatException("invalid count operation (missing rhs) $this");
    }
    final int retval;
    bool test(int v) {
      switch (name) {
        case "#>=": // how many results on lhs are greater than or equal to rhs?
          return v >= target;
        case "#<=": // how many results on lhs are less than or equal to rhs?
          return v <= target;
        case "#>": // how many results on lhs are greater than rhs?
          return v > target;
        case "#<": // how many results on lhs are less than rhs?
          return v < target;
        case "#=": // how many results on lhs are equal to rhs?
          return v == target;
        case '#':
          if (target == -1) {
            // if missing rhs, we're just counting results
            return true;
          } else {
            // if not missing rhs, it's equivalent to '#='
            return v == target;
          }
        default:
          throw FormatException("unknown count operation '$name' in $this");
      }
    }

    retval = rolls.where(test).length;
    return RollResult(name: name, value: retval);
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

  // override call so we can log from within the op method -- that way, we can have single log line that shows results & dropped
  @override
  RollResult call() {
    return eval();
  }

  @override
  RollResult eval() {
    final lhs = left();
    List<int> rolls;
    if (lhs is DiceRollResult) {
      rolls = lhs.rolls;
    } else {
      throw ArgumentError(
        "Invalid operation ($left)$name -- can only drop standard dice rolls",
      );
    }
    final dropTarget = resolveToInt(
      right,
      ifMissingThrowWithMsg: "cannot drop with missing rhs '$right' in $this",
    );

    var results = <int>[];
    var dropped = <int>[];
    switch (name.toUpperCase()) {
      case '-<': // drop <
        results = rolls.where((v) => v >= dropTarget).toList();
        dropped = rolls.where((v) => v < dropTarget).toList();
        break;
      case '-<=': // drop <=
        results = rolls.where((v) => v > dropTarget).toList();
        dropped = rolls.where((v) => v <= dropTarget).toList();
        break;
      case '->': // drop >
        results = rolls.where((v) => v <= dropTarget).toList();
        dropped = rolls.where((v) => v > dropTarget).toList();
        break;
      case '->=': // drop >=
        results = rolls.where((v) => v < dropTarget).toList();
        dropped = rolls.where((v) => v >= dropTarget).toList();
        break;
      case '-=': // drop =
        results = rolls.where((v) => v != dropTarget).toList();
        dropped = rolls.where((v) => v == dropTarget).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }

    ResultStream().publish("dropped: $dropped");
    logger.finer(() => "$this => $results (dropped: $dropped)");
    return DiceRollResult(
      name: name,
      value: results.sum,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolls: results,
    );
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropHighLowOp extends Binary {
  DropHighLowOp(super.name, super.left, super.right);

  // override call so we can log from within the op method -- that way, we can have single log line that shows results & dropped
  @override
  RollResult call() {
    return eval();
  }

  @override
  RollResult eval() {
    final lhs = left();
    List<int> rolls;
    if (lhs is DiceRollResult) {
      rolls = lhs.rolls;
    } else {
      throw ArgumentError(
        "Invalid operation ($left)$name -- can only drop standard dice rolls",
      );
    }
    final sorted = rolls..sort();
    final numToDrop =
        resolveToInt(right, defaultVal: 1); // if missing, assume '1'
    var results = <int>[];
    var dropped = <int>[];
    switch (name.toUpperCase()) {
      case '-H': // drop high
        results = sorted.reversed.skip(numToDrop).toList();
        dropped = sorted.reversed.take(numToDrop).toList();
        break;
      case '-L': // drop low
        results = sorted.skip(numToDrop).toList();
        dropped = sorted.take(numToDrop).toList();
        break;
      case 'KL':
        results = sorted.take(numToDrop).toList();
        dropped = sorted.skip(numToDrop).toList();
        break;
      case 'KH':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
        break;
      case 'K':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }

    ResultStream().publish("dropped: $dropped");
    logger.finer(() => "$this => $results (dropped: $dropped)");
    return DiceRollResult(
      name: name,
      value: results.sum,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolls: results,
    );
  }
}

/// clamp results of lhs to >,< rhs.
class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    List<int> rolls;
    if (lhs is DiceRollResult) {
      rolls = lhs.rolls;
    } else {
      throw ArgumentError(
        "Invalid operation ($left)$name -- can only clamp dice rolls",
      );
    }
    final clampTarget = resolveToInt(
      right,
      ifMissingThrowWithMsg: "cannot clamp with missing rhs '$right' in $this",
    );

    List<int> results;
    switch (name.toUpperCase()) {
      // TODO: does <=,<= make any sense?
      case "C>=": // change any value >= rhs to rhs
        results = rolls.map((v) {
          if (v >= clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C<=": // change any value <= rhs to rhs
        results = rolls.map((v) {
          if (v <= clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C>": // change any value > rhs to rhs
        results = rolls.map((v) {
          if (v > clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C<": // change any value < rhs to rhs
        results = rolls.map((v) {
          if (v < clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
    return DiceRollResult(
      name: name,
      value: results.sum,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolls: results,
    );
  }
}

/// base class for unary dice operations
abstract class UnaryDice extends Unary {
  UnaryDice(super.name, super.left, this.roller);
  final DiceRoller roller;
}

/// base class for binary dice expressions
abstract class BinaryDice extends Binary {
  BinaryDice(super.name, super.left, super.right, this.roller);
  final DiceRoller roller;
}

/// roll fudge dice
class FudgeDice extends UnaryDice {
  FudgeDice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final ndice = resolveToInt(left, defaultVal: 1);
    return roller.rollFudge(ndice);
  }
}

/// roll n % dice
class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final ndice = resolveToInt(left, defaultVal: 1);
    return roller.roll(ndice, 100);
  }
}

/// roll n D66
class D66Dice extends UnaryDice {
  D66Dice(super.name, super.left, super.roller);

  @override
  RollResult eval() {
    final ndice = resolveToInt(left, defaultVal: 1);
    final results = [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6).value * 10 + roller.roll(1, 6).value
    ];
    // TODO: 'D66' is not 'd66', how to resolve?
    return DiceRollResult(
      name: name,
      value: results.sum,
      ndice: ndice,
      nsides: 66,
      rolls: results,
    );
  }
}

/// roll N dice of Y sides.
class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  RollResult eval() {
    final ndice = resolveToInt(left, defaultVal: 1);
    final nsides = resolveToInt(right, defaultVal: 1);

    RangeError.checkValueInInterval(
      ndice,
      DiceRoller.minDice,
      DiceRoller.maxDice,
      '$this: ndice=$ndice',
    );
    RangeError.checkValueInInterval(
      nsides,
      DiceRoller.minSides,
      DiceRoller.maxSides,
      '$this: nsides=$nsides',
    );
    return roller.roll(ndice, nsides);
  }
}

class CompoundingDice extends BinaryDice {
  CompoundingDice(
    super.name,
    super.left,
    super.right,
    super.roller, {
    this.compoundLimit = 100,
  });
  final int compoundLimit;

  @override
  RollResult eval() {
    final lhs = left();
    if (lhs is DiceRollResult) {
      final results = <int>[];
      final nsides = lhs.nsides;

      final compoundTarget =
          resolveToInt(right, defaultVal: nsides); // if missing, assume nsides

      bool test(int val) {
        switch (name) {
          case '!!': // equality
            return val == compoundTarget;
          case '!!=':
            return val == compoundTarget;
          case '!!<':
            return val < compoundTarget;
          case '!!>':
            return val > compoundTarget;
          case '!!<=':
            return val <= compoundTarget;
          case '!!>=':
            return val >= compoundTarget;
          default:
            throw FormatException("unknown explode modifier '$name' in $this");
        }
      }

      lhs.rolls.forEachIndexed((i, v) {
        if (test(v)) {
          int sum = v;
          int rerolled;
          int numCompounded = 0;
          do {
            rerolled = roller
                .roll(1, nsides, "(compound ind $i,  #$numCompounded)")
                .value;
            sum += rerolled;
            numCompounded++;
          } while (test(rerolled) && numCompounded < compoundLimit);
          results.add(sum);
        } else {
          results.add(v);
        }
      });

      return DiceRollResult(
        name: "$left$name",
        value: results.sum,
        ndice: lhs.ndice,
        nsides: lhs.nsides,
        rolls: results,
        allowAdditionalOps: false,
      );
    } else if (lhs is FudgeRollResult) {
      throw ArgumentError("($left)$name - cannot compound fudge dice");
    } else {
      throw ArgumentError("($left)$name - cannot compound arithmetic result");
    }
  }
}

class ExplodingDice extends BinaryDice {
  ExplodingDice(
    super.name,
    super.left,
    super.right,
    super.roller, {
    this.explodeLimit = 100,
  });

  final int explodeLimit;

  @override
  RollResult eval() {
    final lhs = left();

    if (lhs is DiceRollResult) {
      final accumulated = <int>[];

      final nsides = lhs.nsides;
      final explodeTarget =
          resolveToInt(right, defaultVal: nsides); // if missing, assume nsides

      bool test(int val) {
        switch (name) {
          case '!': // equality
            return val == explodeTarget;
          case '!=':
            return val == explodeTarget;
          case '!<':
            return val < explodeTarget;
          case '!>':
            return val > explodeTarget;
          case '!<=':
            return val <= explodeTarget;
          case '!>=':
            return val >= explodeTarget;
          default:
            throw FormatException("unknown explode modifier '$name' in $this");
        }
      }

      accumulated.addAll(lhs.rolls);
      var numToRoll = lhs.rolls.where(test).length;
      var explodeCount = 0;
      while (numToRoll > 0 && explodeCount <= explodeLimit) {
        final results = roller.roll(
          numToRoll,
          nsides,
          "(explode #${explodeCount + 1})",
        );
        accumulated.addAll(results.rolls);
        numToRoll = results.rolls.where(test).length;
        explodeCount++;
      }
      return DiceRollResult(
        name: "$left$name",
        value: accumulated.sum,
        ndice: lhs.ndice,
        nsides: lhs.nsides,
        rolls: accumulated,
      );
    } else if (lhs is FudgeRollResult) {
      throw ArgumentError("($left)$name - cannot explode fudge dice");
    } else {
      throw ArgumentError("($left)$name - cannot explode arithmetic result");
    }
  }
}

/// if input is a Value and empty, return defaultVal.
/// Otherwise, evaluate the expression and return sum.
int resolveToInt(
  DiceExpression expr, {
  int defaultVal = 0,
  String ifMissingThrowWithMsg = "",
}) {
  if (expr is Value && expr.value.isEmpty) {
    if (ifMissingThrowWithMsg.isNotEmpty) {
      throw FormatException(ifMissingThrowWithMsg);
    } else {
      return defaultVal;
    }
  }
  return expr().value;
}
