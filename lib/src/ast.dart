import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/dice_expression.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/results.dart';
import 'package:dart_dice_parser/src/utils.dart';

/// default limit for rerolls/exploding/compounding to avoid getting stuck in loop
const defaultRerollLimit = 1000;

/// A value expression. The token we read from input will be a String,
/// it must parse as an int, and an empty string will return empty set.
class Value extends DiceExpression {
  Value(this.value)
      : _results = RollResult(
          expression: value,
          operation: value,
          results: value.isEmpty ? [] : [int.parse(value)],
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
  // each child class should override this to implement their operation
  RollResult eval();

  // all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  RollResult call() {
    final results = eval();
    logger.finer(() => "$results");
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
      results: [lhs.resolveToInt(() => 0) * rhs.resolveToInt(() => 0)],
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
      results: lhs.results + rhs.results,
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
      results: lhs.results + [rhs.resolveToInt(() => 0) * -1],
      left: lhs,
      right: rhs,
    );
  }
}

enum CountType {
  count(RollMetadata.count),
  success(RollMetadata.successes),
  failure(RollMetadata.failures),
  critSuccess(RollMetadata.critSuccesses),
  critFailure(RollMetadata.critFailures);

  const CountType(this.metadataKey);

  final RollMetadata metadataKey;
}

/// variation on count -- count how many results from lhs are =,<,> rhs.
class CountOp extends Binary {
  CountOp(
    super.name,
    super.left,
    super.right, [
    this.countType = CountType.count,
  ]) {
    if (name.startsWith('#s')) {
      countType = CountType.success;
    } else if (name.startsWith('#f')) {
      countType = CountType.failure;
    } else if (name.startsWith('#cs')) {
      countType = CountType.critSuccess;
    } else if (name.startsWith('#cf')) {
      countType = CountType.critFailure;
    } else {
      countType = CountType.count;
    }
  }

  CountType countType;

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();

    bool rhsEmpty = false;
    final target = rhs.resolveToInt(
      () {
        switch (name) {
          case '#':
            rhsEmpty = true;
            return 0;
          case '#s':
          case '#cs':
            return lhs.nsides;
          case '#f':
          case '#cf':
            return 1;
          default:
            throw FormatException(
              "invalid count operation '$this' -- missing value after '$name'",
            );
        }
      },
    );
    bool test(int v) {
      switch (name) {
        case "#>=": // how many results on lhs are greater than or equal to rhs?
        case "#s>=":
        case "#f>=":
        case "#cs>=":
        case "#cf>=":
          return v >= target;
        case "#<=": // how many results on lhs are less than or equal to rhs?
        case "#s<=":
        case "#f<=":
        case "#cs<=":
        case "#cf<=":
          return v <= target;
        case "#>": // how many results on lhs are greater than rhs?
        case "#s>":
        case "#f>":
        case "#cs>":
        case "#cf>":
          return v > target;
        case "#<": // how many results on lhs are less than rhs?
        case "#s<":
        case "#f<":
        case "#cs<":
        case "#cf<":
          return v < target;
        case "#=": // how many results on lhs are equal to rhs?
        case "#s=":
        case "#f=":
        case "#cs=":
        case "#cf=":
          return v == target;
        case '#':
        case '#s':
        case '#f':
        case '#cs':
        case '#cf':
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

    final count = lhs.results.where(test).length;
    final metadata = <RollMetadata, Object>{};
    metadata.addAll(lhs.metadata);
    metadata.addAll({
      countType.metadataKey: {
        'count': count,
        'target': '$name$target',
      }
    });

    return RollResult(
      operation: name,
      expression: toString(),
      metadata: metadata,
      results: countType == CountType.count ? [count] : lhs.results,
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      left: lhs,
      right: rhs,
    );
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

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
    switch (name) {
      case '-<': // drop <
        results = lhs.results.where((v) => v >= target).toList();
        dropped = lhs.results.where((v) => v < target).toList();
        break;
      case '-<=': // drop <=
        results = lhs.results.where((v) => v > target).toList();
        dropped = lhs.results.where((v) => v <= target).toList();
        break;
      case '->': // drop >
        results = lhs.results.where((v) => v <= target).toList();
        dropped = lhs.results.where((v) => v > target).toList();
        break;
      case '->=': // drop >=
        results = lhs.results.where((v) => v < target).toList();
        dropped = lhs.results.where((v) => v >= target).toList();
        break;
      case '-=': // drop =
        results = lhs.results.where((v) => v != target).toList();
        dropped = lhs.results.where((v) => v == target).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }

    return RollResult(
      operation: name,
      expression: toString(),
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: results,
      metadata: {
        RollMetadata.dropped: dropped,
        RollMetadata.rolled: lhs.results,
      },
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
    final sorted = lhs.results..sort();
    final numToDrop = rhs.resolveToInt(() => 1); // if missing, assume '1'
    var results = <int>[];
    var dropped = <int>[];
    switch (name) {
      case '-h': // drop high
        results = sorted.reversed.skip(numToDrop).toList();
        dropped = sorted.reversed.take(numToDrop).toList();
        break;
      case '-l': // drop low
        results = sorted.skip(numToDrop).toList();
        dropped = sorted.take(numToDrop).toList();
        break;
      case 'kl':
        results = sorted.take(numToDrop).toList();
        dropped = sorted.skip(numToDrop).toList();
        break;
      case 'kh':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
        break;
      case 'k':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
    return RollResult(
      operation: name,
      expression: toString(),
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: results,
      metadata: {
        RollMetadata.dropped: dropped,
        RollMetadata.rolled: sorted,
      },
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
    switch (name) {
      // TODO: does <=,<= make any sense?
      case "c>=": // change any value >= rhs to rhs
        results = lhs.results.map((v) {
          if (v >= target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "c<=": // change any value <= rhs to rhs
        results = lhs.results.map((v) {
          if (v <= target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "c>": // change any value > rhs to rhs
        results = lhs.results.map((v) {
          if (v > target) {
            return target;
          } else {
            return v;
          }
        }).toList();
        break;
      case "c<": // change any value < rhs to rhs
        results = lhs.results.map((v) {
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
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: results,
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
      ndice: ndice,
      results: roll.results,
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
      ndice: ndice,
      nsides: nsides,
      results: roll.results,
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
      ndice: ndice,
      results: results,
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
      ndice: ndice,
      nsides: nsides,
      results: roll.results,
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
    this.limit = defaultRerollLimit,
  }) {
    if (name.startsWith('ro')) {
      limit = 1;
    }
  }
  int limit;

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
        case 'r': // equality
        case 'ro': // equality
        case 'r=':
        case 'ro=':
          return val == target;
        case 'r<':
        case 'ro<':
          return val < target;
        case 'r>':
        case 'ro>':
          return val > target;
        case 'r<=':
        case 'ro<=':
          return val <= target;
        case 'r>=':
        case 'ro>=':
          return val >= target;
        default:
          throw FormatException("unknown reroll modifier '$name' in $this");
      }
    }

    lhs.results.forEachIndexed((i, v) {
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
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: results,
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
    this.limit = defaultRerollLimit,
  }) {
    if (name.startsWith("!!o")) {
      limit = 1;
    }
  }
  int limit;

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
        case '!!=':
        case '!!o':
        case '!!o=':
          return val == target;
        case '!!<':
        case '!!o<':
          return val < target;
        case '!!>':
        case '!!o>':
          return val > target;
        case '!!<=':
        case '!!o<=':
          return val <= target;
        case '!!>=':
        case '!!o>=':
          return val >= target;
        default:
          throw FormatException("unknown explode modifier '$name' in $this");
      }
    }

    final results = <int>[];
    lhs.results.forEachIndexed((i, v) {
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
        } while (test(rerolled) && numCompounded < limit);
        results.add(sum);
      } else {
        results.add(v);
      }
    });

    return RollResult(
      operation: name,
      expression: toString(),
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: results,
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
    this.limit = defaultRerollLimit,
  }) {
    if (name.startsWith('!o')) {
      limit = 1;
    }
  }

  int limit;

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
        case '!=':
        case '!o':
        case '!o=':
          return val == target;
        case '!<':
        case '!o<':
          return val < target;
        case '!>':
        case '!o>':
          return val > target;
        case '!<=':
        case '!o<=':
          return val <= target;
        case '!>=':
        case '!o>=':
          return val >= target;
        default:
          throw FormatException("unknown explode modifier '$name' in $this");
      }
    }

    accumulated.addAll(lhs.results);
    var numToRoll = lhs.results.where(test).length;
    var explodeCount = 0;
    while (numToRoll > 0 && explodeCount < limit) {
      final results = roller.roll(
        numToRoll,
        lhs.nsides,
        "(explode #${explodeCount + 1})",
      );
      accumulated.addAll(results.results);
      numToRoll = results.results.where(test).length;
      explodeCount++;
    }

    return RollResult(
      operation: name,
      expression: toString(),
      ndice: lhs.ndice,
      nsides: lhs.nsides,
      results: accumulated,
      left: lhs,
      right: rhs,
    );
  }
}
