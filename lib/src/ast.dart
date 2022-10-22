import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/dice_expression.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/utils.dart';

/// A value expression. The token we read from input will be a String,
/// an empty string will return empty set.
class Value extends DiceExpression {
  Value(this.value);

  final String value;

  @override
  List<int> call() => value.isEmpty ? [] : [int.parse(value)];

  @override
  String toString() => value;
}

/// All our operations will inherit from this class.
abstract class DiceOp extends DiceExpression with LoggingMixin {
  /// each child class should override this to implement their operation
  List<int> op();

  /// all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  List<int> call() {
    final results = op();
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
  String toString() => '$left$name';
}

/// base class for binary operations
abstract class Binary extends DiceOp {
  Binary(this.name, this.left, this.right);
  final String name;
  final DiceExpression left;
  final DiceExpression right;

  @override
  String toString() => '$left$name$right';
}

/// multiply operation (flattens results)
class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = resolveToInt(left);
    final rhs = resolveToInt(right);
    return [lhs * rhs];
  }
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    return left() + right(); // concat the two results together
  }
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = resolveToInt(left);
    final rhs = resolveToInt(right);
    return [lhs - rhs];
  }
}

/// perform lhs operation, and count results.
class CountResults extends Unary {
  CountResults(super.name, super.left);

  @override
  List<int> op() {
    return [left().length];
  }
}

/// variation on count -- count how many results from lhs are =,<,> rhs.
class CountOp extends Binary {
  CountOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = left();
    final target = resolveToInt(right, 1); // if missing, assume '1'
    switch (name) {
      case "#>": // how many results on lhs are greater than rhs?
        return [lhs.where((v) => v > target).length];
      case "#<": // how many results on lhs are less than rhs?
        return [lhs.where((v) => v < target).length];
      case "#=": // how many results on lhs are equal to rhs?
        return [lhs.where((v) => v == target).length];
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

  // override call so we can log from within the op method -- that way, we can have single log line that shows results & dropped
  @override
  List<int> call() {
    return op();
  }

  @override
  List<int> op() {
    final lhs = left();
    final numToDrop = resolveToInt(right, 1); // if missing, assume '1'
    var results = <int>[];
    var dropped = <int>[];
    switch (name.toUpperCase()) {
      case '-<': // drop less than
        results = lhs.where((v) => v >= numToDrop).toList();
        dropped = lhs.where((v) => v < numToDrop).toList();
        break;
      case '->': // drop greater than
        results = lhs.where((v) => v <= numToDrop).toList();
        dropped = lhs.where((v) => v > numToDrop).toList();
        break;
      case '-=': // drop equal
        results = lhs.where((v) => v != numToDrop).toList();
        dropped = lhs.where((v) => v == numToDrop).toList();
        break;
      case '-H': // drop high
        final sorted = lhs..sort();
        results = sorted.reversed.skip(numToDrop).toList();
        dropped = sorted.reversed.take(numToDrop).toList();
        break;
      case '-L': // drop low
        final sorted = lhs..sort();
        results = sorted.skip(numToDrop).toList();
        dropped = sorted.take(numToDrop).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }

    logger.finer(() => "$this => $results (dropped: $dropped)");
    return results;
  }
}

/// clamp results of lhs to >,< rhs.
class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = left();
    final clampTarget = resolveToInt(right, 1); // if missing, assume '1'
    switch (name.toUpperCase()) {
      case "C>": // change any value greater than rhs to rhs
        return lhs.map((v) {
          if (v > clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
      case "C<": // change any value less than rhs to rhs
        return lhs.map((v) {
          if (v < clampTarget) {
            return clampTarget;
          } else {
            return v;
          }
        }).toList();
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
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
  List<int> op() {
    final ndice = resolveToInt(left, 1);
    return roller.rollFudge(ndice);
  }
}

/// roll n % dice
class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left, 1);
    return roller.roll(ndice, 100);
  }
}

/// roll n D66
class D66Dice extends UnaryDice {
  D66Dice(super.name, super.left, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left, 1);
    return [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6)[0] * 10 + roller.roll(1, 6)[0]
    ];
  }
}

/// roll N dice of Y sides.
class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left, 1);
    final nsides = resolveToInt(right, 1);
    return roller.roll(ndice, nsides);
  }
}

/// roll N dice of Y sides, and explode results (re-roll)
class ExplodeDice extends BinaryDice {
  ExplodeDice(
    super.name,
    super.left,
    super.right,
    super.roller, [
    this.explodeLimit = DiceRoller.defaultExplodeLimit,
  ]);
  int explodeLimit;

  @override
  List<int> op() {
    final ndice = resolveToInt(left, 1);
    final nsides = resolveToInt(right, 1);
    return roller.rollWithExplode(
      ndice: ndice,
      nsides: nsides,
      explode: true,
      explodeLimit: explodeLimit,
    );
  }
}

/// if input is a Value and empty, return defaultVal.
/// Otherwise, evaluate the expression and return sum.
int resolveToInt(DiceExpression expr, [int defaultVal = 0]) {
  if (expr is Value) {
    if (expr.value.isEmpty) {
      return defaultVal;
    }
  }
  return expr().sum;
}
