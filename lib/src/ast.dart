import 'dart:math';

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
          expression: value,
          operation: value,
          operationType: OperationType.value,
          rolled: value.isEmpty ? [] : [int.parse(value)],
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
    final lhs = left();
    final rhs = right();
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.multiply,
      rolled: [lhs.resolveToInt(() => 0) * rhs.resolveToInt(() => 0)],
      left: lhs,
      right: rhs,
    );
  }
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.add,
      rolled: lhs.rolled + rhs.rolled,
      ndice: max(lhs.ndice, rhs.ndice),
      nsides: max(lhs.nsides, rhs.nsides),
      left: lhs,
      right: rhs,
    );
  }
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.subtract,
      rolled: lhs.rolled + [rhs.resolveToInt(() => 0) * -1],
      left: lhs,
      right: rhs,
    );
  }
}

/// variation on count -- count how many results from lhs are =,<,> rhs.
class CountOp extends Binary {
  CountOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();

    bool rhsEmpty = false;
    final target = rhs.resolveToInt(
      () {
        if (name != '#') {
          throw FormatException(
            "invalid count operation '$this' -- missing value after '$name'",
          );
        } else {
          // if operation is simple '#', return 0 and set flag
          rhsEmpty = true;
          return 0;
        }
      },
    );
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
          if (rhsEmpty) {
            // if missing rhs, we're just counting results
            // that is, '3d6#' should return 3
            return true;
          } else {
            // if not missing rhs, treat it as equivalent to '#='.
            // that is, '3d6#2' should count 2s
            return v == target;
          }
        default:
          throw FormatException("unknown count operation '$name' in $this");
      }
    }

    retval = lhs.rolled.where(test).length;
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.count,
      rolled: [retval],
      // TODO: add count results to metadata?
      left: lhs,
      right: rhs,
    );
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
    final rhs = right();

    final target = rhs.resolveToInt(() {
      throw FormatException(
        "invalid drop operation '$this' -- missing value after '$name'",
      );
    });

    var results = <int>[];
    var dropped = <int>[];
    switch (name.toUpperCase()) {
      case '-<': // drop <
        results = lhs.rolled.where((v) => v >= target).toList();
        dropped = lhs.rolled.where((v) => v < target).toList();
        break;
      case '-<=': // drop <=
        results = lhs.rolled.where((v) => v > target).toList();
        dropped = lhs.rolled.where((v) => v <= target).toList();
        break;
      case '->': // drop >
        results = lhs.rolled.where((v) => v <= target).toList();
        dropped = lhs.rolled.where((v) => v > target).toList();
        break;
      case '->=': // drop >=
        results = lhs.rolled.where((v) => v < target).toList();
        dropped = lhs.rolled.where((v) => v >= target).toList();
        break;
      case '-=': // drop =
        results = lhs.rolled.where((v) => v != target).toList();
        dropped = lhs.rolled.where((v) => v == target).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }

    logger.finer(() => "$this => $results (dropped: $dropped)");
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.drop,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: results,
      dropped: dropped,
      left: lhs,
      right: rhs,
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
    final rhs = right();
    final sorted = lhs.rolled..sort();
    final numToDrop = rhs.resolveToInt(() => 1); // if missing, assume '1'
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

    logger.finer(() => "$this => $results (dropped: $dropped)");
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.dropHighLow,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: results,
      dropped: dropped,
      left: lhs,
      right: rhs,
    );
  }
}

/// clamp results of lhs to >,< rhs.
class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    final target = rhs.resolveToInt(() {
      throw FormatException(
        "invalid clamp operation '$this' -- missing value after '$name'",
      );
    });

    List<int> results;
    switch (name.toUpperCase()) {
      // TODO: does <=,<= make any sense?
      case "C>=": // change any value >= rhs to rhs
        results = lhs.rolled.map((v) {
          if (v >= target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C<=": // change any value <= rhs to rhs
        results = lhs.rolled.map((v) {
          if (v <= target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C>": // change any value > rhs to rhs
        results = lhs.rolled.map((v) {
          if (v > target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "C<": // change any value < rhs to rhs
        results = lhs.rolled.map((v) {
          if (v < target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.clamp,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: results,
      left: lhs,
      right: rhs,
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
    final lhs = left();
    final ndice = lhs.resolveToInt(() => 1);
    final roll = roller.rollFudge(ndice);

    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.diceFudge,
      ndice: ndice,
      rolled: roll.rolled,
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
    const nsides = 100;
    final ndice = lhs.resolveToInt(() => 1);
    final roll = roller.roll(ndice, nsides);
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.dice,
      ndice: ndice,
      nsides: nsides,
      rolled: roll.rolled,
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
    final ndice = lhs.resolveToInt(() => 1);
    final results = [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6).resolveToInt() * 10 + roller.roll(1, 6).resolveToInt()
    ];
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.dice66,
      ndice: ndice,
      rolled: results,
      left: lhs,
    );
  }
}

/// roll N dice of Y sides.
class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    final ndice = lhs.resolveToInt(() => 1);
    final nsides = rhs.resolveToInt(() => 1);

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
    final roll = roller.roll(ndice, nsides);
    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.dice,
      ndice: ndice,
      nsides: nsides,
      rolled: roll.rolled,
      left: lhs,
      right: rhs,
    );
  }
}

class RerollDice extends BinaryDice {
  RerollDice(
    super.name,
    super.left,
    super.right,
    super.roller, {
    this.limit = 100,
  });
  final int limit;

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();

    if (lhs.nsides == 0) {
      throw ArgumentError(
        "Invalid reroll operation '$this' -- cannot determine # sides from '$left'",
      );
    }
    final target = rhs.resolveToInt(() {
      throw FormatException(
        "invalid reroll operation '$this' -- missing value after '$name'",
      );
    });
    final results = <int>[];

    bool test(int val) {
      switch (name) {
        case 'R': // equality
          return val == target;
        case 'R=':
          return val == target;
        case 'R<':
          return val < target;
        case 'R>':
          return val > target;
        case 'R<=':
          return val <= target;
        case 'R>=':
          return val >= target;
        default:
          throw FormatException("unknown reroll modifier '$name' in $this");
      }
    }

    lhs.rolled.forEachIndexed((i, v) {
      if (test(v)) {
        int rerolled;
        int rerollCount = 0;
        do {
          rerolled = roller
              .roll(1, lhs.nsides, "(reroll ind $i,  #$rerollCount)")
              .total;
          rerollCount++;
        } while (test(rerolled) && rerollCount < limit);
        results.add(rerolled);
      } else {
        results.add(v);
      }
    });

    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.reroll,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: results,
      left: lhs,
      right: rhs,
    );
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
    final rhs = right();

    if (lhs.nsides == 0) {
      throw ArgumentError(
        "Invalid compounding operation '$this' -- cannot determine # sides from '$left'",
      );
    }
    final target = rhs.resolveToInt(() => lhs.nsides);
    bool test(int val) {
      switch (name) {
        case '!!': // equality
          return val == target;
        case '!!=':
          return val == target;
        case '!!<':
          return val < target;
        case '!!>':
          return val > target;
        case '!!<=':
          return val <= target;
        case '!!>=':
          return val >= target;
        default:
          throw FormatException("unknown explode modifier '$name' in $this");
      }
    }

    final results = <int>[];
    lhs.rolled.forEachIndexed((i, v) {
      if (test(v)) {
        int sum = v;
        int rerolled;
        int numCompounded = 0;
        do {
          rerolled = roller
              .roll(1, lhs.nsides, "(compound ind $i,  #$numCompounded)")
              .total;
          sum += rerolled;
          numCompounded++;
        } while (test(rerolled) && numCompounded < compoundLimit);
        results.add(sum);
      } else {
        results.add(v);
      }
    });

    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.compound,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: results,
      left: lhs,
      right: rhs,
    );
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
    final rhs = right();

    if (lhs.nsides == 0) {
      throw ArgumentError(
        "Invalid exploding operation '$this' -- cannot determine # sides from '$left'",
      );
    }
    final target = rhs.resolveToInt(() => lhs.nsides);

    final accumulated = <int>[];

    bool test(int val) {
      switch (name) {
        case '!': // equality
          return val == target;
        case '!=':
          return val == target;
        case '!<':
          return val < target;
        case '!>':
          return val > target;
        case '!<=':
          return val <= target;
        case '!>=':
          return val >= target;
        default:
          throw FormatException("unknown explode modifier '$name' in $this");
      }
    }

    accumulated.addAll(lhs.rolled);
    var numToRoll = lhs.rolled.where(test).length;
    var explodeCount = 0;
    while (numToRoll > 0 && explodeCount <= explodeLimit) {
      final results = roller.roll(
        numToRoll,
        lhs.nsides,
        "(explode #${explodeCount + 1})",
      );
      accumulated.addAll(results.rolled);
      numToRoll = results.rolled.where(test).length;
      explodeCount++;
    }

    return RollResult(
      operation: name,
      expression: toString(),
      operationType: OperationType.explode,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      rolled: accumulated,
      left: lhs,
      right: rhs,
    );
  }
}
