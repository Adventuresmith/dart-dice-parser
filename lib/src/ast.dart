import 'package:collection/collection.dart';
import 'package:petitparser/parser.dart';

import 'dice_expression.dart';
import 'dice_roller.dart';
import 'results.dart';
import 'utils.dart';

/// default limit for rerolls/exploding/compounding to avoid getting stuck in loop
const defaultRerollLimit = 1000;

/// A value expression. The token we read from input will be a String,
/// it must parse as an int, and an empty string will return empty set.
class SimpleValue extends DiceExpression {
  SimpleValue(this.value)
    : _results = RollResult(
        expression: value,
        opType: OpType.value,
        results: value.isEmpty
            ? []
            : [RolledDie.singleVal(result: int.parse(value))],
      );

  final String value;
  final RollResult _results;

  @override
  RollResult call() => _results;

  @override
  String toString() => value;
}

/// All our operations will inherit from this class.
/// The `call()` method will be called by the parent node.
/// The `eval()` method is called from the node
abstract class DiceOp extends DiceExpression with LoggingMixin {
  // each child class should override this to implement their operation
  RollResult eval();

  // all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  RollResult call() {
    final result = eval();
    logger.finer(() => '$result');
    return result;
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
  String toString() => '($left $name $right)';
}

/// multiply operation (flattens results)
class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() * right();
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() + right();
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() - right();
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

    bool test(RolledDie rolledDie) {
      var rhsEmptyAndSimpleCount = false;
      final target = rhs.totalOrDefault(() {
        // if missing RHS, we can make assumptions depending on operator.
        switch (name) {
          case '#':
            // example: '3d6#' should be 3. target is ignored in case statement below.
            rhsEmptyAndSimpleCount = true;
            return 0;
          case '#s' || '#cs':
            // example: '3d6#s' -- assume target is nsides (maximum)
            return rolledDie.nsides;
          case '#f' || '#cf':
            // example: '3d6#f' -- assume target is 1 (minimum)
            return 1;
          default:
            throw FormatException(
              'Invalid count operation. Missing count target',
              toString(),
              toString().length,
            );
        }
      });
      final v = rolledDie.result;
      switch (name) {
        case '#>=' || '#s>=' || '#f>=' || '#cs>=' || '#cf>=':
          // how many results on lhs are greater than or equal to rhs?
          return v >= target;
        case '#<=' || '#s<=' || '#f<=' || '#cs<=' || '#cf<=':
          // how many results on lhs are less than or equal to rhs?
          return v <= target;
        case '#>' || '#s>' || '#f>' || '#cs>' || '#cf>':
          // how many results on lhs are greater than rhs?
          return v > target;
        case '#<' || '#s<' || '#f<' || '#cs<' || '#cf<':
          // how many results on lhs are less than rhs?
          return v < target;
        case '#=' || '#s=' || '#f=' || '#cs=' || '#cf=':
          // how many results on lhs are equal to rhs?
          return v == target;
        case '#' || '#s' || '#f' || '#cs' || '#cf':
          if (rhsEmptyAndSimpleCount) {
            // if missing rhs, we're just counting results
            // that is, '3d6#' should return 3
            return true;
          } else {
            // if not missing rhs, treat it as equivalent to '#='.
            // that is, '3d6#2' should count 2s
            return v == target;
          }
        default:
          throw FormatException(
            "unknown count operation '$name'",
            toString(),
            toString().indexOf(name),
          );
      }
    }

    final filteredResults = lhs.results.notDiscarded.where(test);

    if (countType == CountType.count) {
      // if counting, the count becomes the new result

      return RollResult(
        expression: toString(),
        opType: OpType.count,
        results: [
          RolledDie.singleVal(result: filteredResults.length),
          ...lhs.results.notDiscarded.map(RolledDie.discard),
          ...lhs.results.discarded,
        ],
        left: lhs,
        right: rhs,
      );
    } else {
      // if counting success/failures, the results are updated w/ scoring

      final otherResults = lhs.results.notDiscarded.whereNot(test);

      return RollResult(
        expression: toString(),
        opType: OpType.count,
        results: [
          ...filteredResults.map(
            (v) => RolledDie.scoreForCountType(v, countType: countType),
          ),
          ...otherResults,
          ...lhs.results.discarded,
        ],
        left: lhs,
        right: rhs,
      );
    }
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();

    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid drop operation. Missing drop target',
        toString(),
        toString().length,
      );
    });

    final Iterable<RolledDie> results;
    final Iterable<RolledDie> dropped;
    final notDiscarded = lhs.results.notDiscarded;
    switch (name) {
      case '-<': // drop <
        results = notDiscarded.where((v) => v.result >= target);
        dropped = notDiscarded.where((v) => v.result < target);
      case '-<=': // drop <=
        results = notDiscarded.where((v) => v.result > target);
        dropped = notDiscarded.where((v) => v.result <= target);
      case '->': // drop >
        results = notDiscarded.where((v) => v.result <= target);
        dropped = notDiscarded.where((v) => v.result > target);
      case '->=': // drop >=
        results = notDiscarded.where((v) => v.result < target);
        dropped = notDiscarded.where((v) => v.result >= target);
      case '-=': // drop =
        results = notDiscarded.where((v) => v.result != target);
        dropped = notDiscarded.where((v) => v.result == target);
      default:
        throw FormatException(
          "unknown drop operation '$name'",
          toString(),
          toString().indexOf(name),
        );
    }

    return RollResult(
      expression: toString(),
      opType: OpType.drop,
      results: [
        ...results,
        ...dropped.map(RolledDie.discard),
        ...lhs.results.discarded,
      ],
      left: lhs,
      right: rhs,
    );
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropHighLowOp extends Binary {
  DropHighLowOp(super.name, super.left, super.right);

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();
    final sorted = lhs.results.notDiscarded.toList()..sort();
    final numToDrop = rhs.totalOrDefault(() => 1); // if missing, assume '1'
    final Iterable<RolledDie> results;
    final Iterable<RolledDie> dropped;
    switch (name) {
      case '-h': // drop high
        results = sorted.reversed.skip(numToDrop);
        dropped = sorted.reversed.take(numToDrop);
      case '-l': // drop low
        results = sorted.skip(numToDrop);
        dropped = sorted.take(numToDrop);
      case 'kl':
        results = sorted.take(numToDrop);
        dropped = sorted.skip(numToDrop);
      case 'kh':
        results = sorted.reversed.take(numToDrop);
        dropped = sorted.reversed.skip(numToDrop);
      case 'k':
        results = sorted.reversed.take(numToDrop);
        dropped = sorted.reversed.skip(numToDrop);
      default:
        throw FormatException(
          "unknown drop operation '$name'",
          toString(),
          toString().indexOf(name),
        );
    }
    return RollResult(
      expression: toString(),
      opType: OpType.drop,
      results: [
        ...results,
        ...dropped.map(RolledDie.discard),
        ...lhs.results.discarded,
      ],
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
    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid clamp operation. Missing clamp target',
        toString(),
        toString().length,
      );
    });

    final newResults = <RolledDie>[];
    for (final d in lhs.results.notDiscarded) {
      if (name == 'c>' && d.result > target) {
        newResults.add(RolledDie.copyWith(d, result: target, clampHigh: true));
      } else if (name == 'c<' && d.result < target) {
        newResults.add(RolledDie.copyWith(d, result: target, clampLow: true));
      } else {
        newResults.add(d);
      }
    }
    return RollResult(
      expression: toString(),
      opType: OpType.clamp,
      results: [...newResults, ...lhs.results.discarded],
      left: lhs,
      right: rhs,
    );
  }
}

/// base class for unary dice operations
abstract class UnaryDice extends Unary {
  UnaryDice(super.name, super.left, this.roller);

  final DiceRoller roller;

  @override
  String toString() => '($left$name)';
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

    final roll = roller.rollVals(
      ndice,
      vals.elements.map(int.parse).toList(growable: false),
    );

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
    final results = [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6).total * 10 + roller.roll(1, 6).total,
    ].map((i) => RolledDie.d66(result: i));
    return RollResult(
      expression: toString(),
      opType: OpType.rollD66,
      results: [...results],
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

    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid reroll operation. Missing reroll target',
        toString(),
        toString().length,
      );
    });

    bool test(RolledDie rolledDie) {
      final val = rolledDie.result;
      switch (name) {
        case 'r' || 'ro' || 'r=' || 'ro=':
          return val == target;
        case 'r<' || 'ro<':
          return val < target;
        case 'r>' || 'ro>':
          return val > target;
        case 'r<=' || 'ro<=':
          return val <= target;
        case 'r>=' || 'ro>=':
          return val >= target;
        default:
          throw FormatException(
            "unknown reroll operation '$name'",
            toString(),
            toString().indexOf(name),
          );
      }
    }

    final results = <RolledDie>[];
    lhs.results.notDiscarded.forEachIndexed((i, v) {
      if (test(v)) {
        RolledDie rerolled;
        var rerollCount = 0;
        do {
          rerolled = roller
              .roll(1, v.nsides, '(reroll ind $i,  #$rerollCount)')
              .results[0];
          rerollCount++;
        } while (test(rerolled) && rerollCount < limit);
        results.add(
          RolledDie.copyWith(v, result: rerolled.result, rerolled: true),
        );
      } else {
        results.add(v);
      }
    });

    return RollResult(
      expression: toString(),
      opType: OpType.reroll,
      results: [...results, ...lhs.results.discarded],
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
    if (name.startsWith('!!o')) {
      limit = 1;
    }
  }

  int limit;

  @override
  RollResult eval() {
    final lhs = left();
    final rhs = right();

    bool test(RolledDie rolledDie) {
      final target = rhs.totalOrDefault(() => rolledDie.nsides);
      final val = rolledDie.result;
      if (!rolledDie.isCompoundable) {
        return false;
      }
      switch (name) {
        case '!!' || '!!=' || '!!o' || '!!o=':
          return val == target;
        case '!!<' || '!!o<':
          return val < target;
        case '!!>' || '!!o>':
          return val > target;
        case '!!<=' || '!!o<=':
          return val <= target;
        case '!!>=' || '!!o>=':
          return val >= target;
        default:
          throw FormatException(
            "unknown compounding operation '$name'",
            toString(),
            toString().indexOf(name),
          );
      }
    }

    final results = <RolledDie>[];
    lhs.results.notDiscarded.forEachIndexed((i, v) {
      if (test(v)) {
        var sum = v.result;
        RolledDie rerolled;
        var numCompounded = 0;
        do {
          rerolled = roller
              .roll(1, v.nsides, '(compound ind $i,  #$numCompounded)')
              .results[0];
          sum += rerolled.result;
          numCompounded++;
        } while (test(rerolled) && numCompounded < limit);
        results.add(RolledDie.copyWith(v, result: sum, compounded: true));
      } else {
        results.add(v);
      }
    });

    return RollResult(
      expression: toString(),
      opType: OpType.compound,
      results: [...results, ...lhs.results.discarded],
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

    bool test(RolledDie rolledDie) {
      final target = rhs.totalOrDefault(() => rolledDie.nsides);
      final val = rolledDie.result;
      if (!rolledDie.isExplodable) {
        return false;
      }
      switch (name) {
        case '!' || '!=' || '!o' || '!o=':
          return val == target;
        case '!<' || '!o<':
          return val < target;
        case '!>' || '!o>':
          return val > target;
        case '!<=' || '!o<=':
          return val <= target;
        case '!>=' || '!o>=':
          return val >= target;
        default:
          throw FormatException(
            "unknown explode operation '$name'",
            toString(),
            toString().indexOf(name),
          );
      }
    }

    final newResults = <RolledDie>[];
    for (final rolledDie in lhs.results.notDiscarded.where(test)) {
      var numExplosions = 0;
      RolledDie rerolledDie;
      do {
        rerolledDie = roller
            .roll(1, rolledDie.nsides, '(explode #${numExplosions + 1})')
            .results[0];
        numExplosions++;
        newResults.add(RolledDie.copyWith(rolledDie, exploded: true));
        newResults.add(RolledDie.copyWith(rerolledDie, explosion: true));
      } while (test(rerolledDie) && numExplosions < limit);
    }

    return RollResult(
      expression: toString(),
      opType: OpType.explode,
      results: [
        ...newResults,
        ...lhs.results.notDiscarded.whereNot(test),
        ...lhs.results.discarded,
      ],
      left: lhs,
      right: rhs,
    );
  }
}
