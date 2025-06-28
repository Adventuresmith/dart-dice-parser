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
          results: value.isEmpty ? [] : [int.parse(value)],
        );

  final String value;
  final RollResult _results;

  @override
  Future<RollResult> call() async => _results;

  @override
  String toString() => value;
}

/// All our operations will inherit from this class.
/// The `call()` method will be called by the parent node.
/// The `eval()` method is called from the node
abstract class DiceOp extends DiceExpression with LoggingMixin {
  // each child class should override this to implement their operation
  Future<RollResult> eval();

  // all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  Future<RollResult> call() {
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
  Future<RollResult> eval() async {
    final results = await Future.wait([left(), right()]);
    return results[0] * results[1];
  }
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final results = await Future.wait([left(), right()]);
    return results[0] + results[1];
  }
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final results = await Future.wait([left(), right()]);
    return results[0] - results[1];
  }
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
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();
    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    var rhsEmptyAndSimpleCount = false;
    final target = finalRight.totalOrDefault(
      () {
        // if missing RHS, we can make assumptions depending on operator.
        //
        switch (name) {
          case '#':
            // example: '3d6#' should be 3. target is ignored in case statement below.
            rhsEmptyAndSimpleCount = true;
            return 0;
          case '#s' || '#cs':
            // example: '3d6#s' -- assume target is nsides (maximum)
            return finalLeft.nsides;
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
      },
    );
    bool test(int v) {
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

    final filteredResults = finalLeft.results.where(test);

    if (countType == CountType.count) {
      // if counting, the count becomes the new result

      return RollResult(
        expression: toString(),
        opType: OpType.count,
        metadata: RollMetadata(
          discarded: finalLeft.results,
        ),
        results: [filteredResults.length],
        ndice: finalLeft.ndice,
        nsides: finalLeft.nsides,
        left: finalLeft,
        right: finalRight,
      );
    } else {
      // if counting success/failures, the results are unchanged

      return RollResult(
        expression: toString(),
        results: finalLeft.results,
        opType: OpType.count,
        metadata: RollMetadata(
          score: RollScore.forCountType(countType, List.of(filteredResults)),
        ),
        ndice: finalLeft.ndice,
        nsides: finalLeft.nsides,
        left: finalLeft,
        right: finalRight,
      );
    }
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    final target = finalRight.totalOrDefault(() {
      throw FormatException(
        'Invalid drop operation. Missing drop target',
        toString(),
        toString().length,
      );
    });

    var results = <int>[];
    var dropped = <int>[];
    switch (name) {
      case '-<': // drop <
        results = finalLeft.results.where((v) => v >= target).toList();
        dropped = finalLeft.results.where((v) => v < target).toList();
      case '-<=': // drop <=
        results = finalLeft.results.where((v) => v > target).toList();
        dropped = finalLeft.results.where((v) => v <= target).toList();
      case '->': // drop >
        results = finalLeft.results.where((v) => v <= target).toList();
        dropped = finalLeft.results.where((v) => v > target).toList();
      case '->=': // drop >=
        results = finalLeft.results.where((v) => v < target).toList();
        dropped = finalLeft.results.where((v) => v >= target).toList();
      case '-=': // drop =
        results = finalLeft.results.where((v) => v != target).toList();
        dropped = finalLeft.results.where((v) => v == target).toList();
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
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: results,
      metadata: RollMetadata(
        discarded: dropped,
      ),
      left: finalLeft,
      right: finalRight,
    );
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropHighLowOp extends Binary {
  DropHighLowOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    final sorted = finalLeft.results..sort();
    final numToDrop =
        finalRight.totalOrDefault(() => 1); // if missing, assume '1'
    var results = <int>[];
    var dropped = <int>[];
    switch (name) {
      case '-h': // drop high
        results = sorted.reversed.skip(numToDrop).toList();
        dropped = sorted.reversed.take(numToDrop).toList();
      case '-l': // drop low
        results = sorted.skip(numToDrop).toList();
        dropped = sorted.take(numToDrop).toList();
      case 'kl':
        results = sorted.take(numToDrop).toList();
        dropped = sorted.skip(numToDrop).toList();
      case 'kh':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
      case 'k':
        results = sorted.reversed.take(numToDrop).toList();
        dropped = sorted.reversed.skip(numToDrop).toList();
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
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: results,
      metadata: RollMetadata(
        discarded: dropped,
      ),
      left: finalLeft,
      right: finalRight,
    );
  }
}

/// clamp results of lhs to >,< rhs.
class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    final target = finalRight.totalOrDefault(() {
      throw FormatException(
        'Invalid clamp operation. Missing clamp target',
        toString(),
        toString().length,
      );
    });

    List<int> results;
    final discarded = <int>[];
    final added = <int>[];
    switch (name) {
      case 'c>': // change any value > rhs to rhs
        results = finalLeft.results.map((v) {
          if (v > target) {
            discarded.add(v);
            added.add(target);
            return target;
          } else {
            return v;
          }
        }).toList();
      case 'c<': // change any value < rhs to rhs
        results = finalLeft.results.map((v) {
          if (v < target) {
            discarded.add(v);
            added.add(target);
            return target;
          } else {
            return v;
          }
        }).toList();
      default:
        throw FormatException(
          "unknown clamp operation '$name'",
          toString(),
          toString().indexOf(name),
        );
    }
    return RollResult(
      expression: toString(),
      opType: OpType.clamp,
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: results,
      metadata: RollMetadata(
        discarded: discarded,
        rolled: added,
      ),
      left: finalLeft,
      right: finalRight,
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
      metadata: RollMetadata(
        rolled: roll.results,
      ),
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

    final roll =
        await roller.rollVals(ndice, vals.elements.map(int.parse).toList());

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
  Future<RollResult> eval() async {
    final lhs = await left();
    const nsides = 100;
    final ndice = lhs.totalOrDefault(() => 1);
    final roll = await roller.roll(ndice, nsides);
    return RollResult.fromRollResult(
      roll,
      expression: toString(),
      opType: OpType.rollPercent,
      metadata: RollMetadata(
        rolled: roll.results,
      ),
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
    // Roll all dice at once, then compute D66 values.
    final tensRolls =
        await Future.wait(List.generate(ndice, (_) => roller.roll(1, 6)));
    final onesRolls =
        await Future.wait(List.generate(ndice, (_) => roller.roll(1, 6)));
    final results = List.generate(
      ndice,
      (i) => tensRolls[i].results.sum * 10 + onesRolls[i].results.sum,
    );
    return RollResult(
      expression: toString(),
      opType: OpType.rollD66,
      ndice: ndice,
      results: results,
      metadata: RollMetadata(
        rolled: results,
      ),
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
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    final ndice = finalLeft.totalOrDefault(() => 1);
    final nsides = finalRight.totalOrDefault(() => 1);

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
      metadata: RollMetadata(
        rolled: roll.results,
      ),
      left: finalLeft,
      right: finalRight,
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
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    if (finalLeft.nsides == 0) {
      throw FormatException(
        "Invalid reroll operation. Cannot determine # sides from '$left'",
        toString(),
        left.toString().length,
      );
    }
    final target = finalRight.totalOrDefault(() {
      throw FormatException(
        'Invalid reroll operation. Missing reroll target',
        toString(),
        toString().length,
      );
    });
    final results = <int>[];
    final discarded = <int>[];
    final added = <int>[];

    bool test(int val) {
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

    // Prepare a list of futures for all rerolls that need to be performed.
    final rerollFutures = <Future<int>>[];
    final rerollIndices = <int>[];

    for (var i = 0; i < finalLeft.results.length; i++) {
      final v = finalLeft.results[i];
      if (test(v)) {
        // Schedule reroll for this index.
        rerollIndices.add(i);
        // Chain rerolls up to the limit.
        Future<int> rerollFuture(int rerollCount, int lastValue) async {
          if (rerollCount >= limit || !test(lastValue)) return lastValue;
          final rerolled = (await roller.roll(
                  1, finalLeft.nsides, '(reroll ind $i,  #$rerollCount)'))
              .results
              .sum;
          return rerollFuture(rerollCount + 1, rerolled);
        }

        rerollFutures.add(rerollFuture(0, v));
      }
    }

    // Await all rerolls in parallel.
    final rerolledValues = await Future.wait(rerollFutures);

    int rerollIdx = 0;
    for (var i = 0; i < finalLeft.results.length; i++) {
      final v = finalLeft.results[i];
      if (test(v)) {
        final rerolled = rerolledValues[rerollIdx++];
        results.add(rerolled);
        discarded.add(v);
        added.add(rerolled);
      } else {
        results.add(v);
      }
    }

    return RollResult(
      expression: toString(),
      opType: OpType.reroll,
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: results,
      metadata: RollMetadata(
        rolled: added,
        discarded: discarded,
      ),
      left: finalLeft,
      right: finalRight,
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
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    if (finalLeft.nsides == 0) {
      throw FormatException(
        "Invalid compounding operation. Cannot determine # sides from '$left'",
        toString(),
        left.toString().length,
      );
    }
    final target = finalRight.totalOrDefault(() => finalLeft.nsides);
    bool test(int val) {
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

    final results = <int>[];
    final discarded = <int>[];
    final added = <int>[];
    // Prepare a list of compound roll futures for all dice that need compounding.
    final compoundFutures = <Future<int>>[];
    final compoundIndices = <int>[];

    for (var i = 0; i < finalLeft.results.length; i++) {
      final v = finalLeft.results[i];
      if (test(v)) {
        compoundIndices.add(i);
        // Chain compounding rolls up to the limit.
        Future<int> compoundFuture(
            int compoundCount, int sum, int lastValue) async {
          if (compoundCount >= limit || !test(lastValue)) return sum;
          final rolled = (await roller.roll(
                  1, finalLeft.nsides, '(compound ind $i,  #$compoundCount)'))
              .results
              .sum;
          return compoundFuture(compoundCount + 1, sum + rolled, rolled);
        }

        compoundFutures.add(compoundFuture(0, v, v));
      }
    }

    // Await all compounding rolls in parallel.
    final compoundedValues = await Future.wait(compoundFutures);

    int compoundIdx = 0;
    for (var i = 0; i < finalLeft.results.length; i++) {
      final v = finalLeft.results[i];
      if (test(v)) {
        final compounded = compoundedValues[compoundIdx++];
        results.add(compounded);
        discarded.add(v);
        added.add(compounded);
      } else {
        results.add(v);
      }
    }

    return RollResult(
      expression: toString(),
      opType: OpType.compound,
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: results,
      metadata: RollMetadata(
        rolled: added,
        discarded: discarded,
      ),
      left: finalLeft,
      right: finalRight,
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
  Future<RollResult> eval() async {
    final lhs = left();
    final rhs = right();

    final leftRight = await Future.wait([lhs, rhs]);
    final finalLeft = leftRight[0];
    final finalRight = leftRight[1];

    if (finalLeft.nsides == 0) {
      throw FormatException(
        "Invalid exploding operation. Cannot determine # sides from '$left'",
        toString(),
        left.toString().length,
      );
    }
    final target = finalRight.totalOrDefault(() => finalLeft.nsides);

    final allResults = <int>[];
    final newResults = <int>[];

    bool test(int val) {
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

    allResults.addAll(finalLeft.results);
    var numToRoll = finalLeft.results.where(test).length;
    var explodeCount = 0;
    while (numToRoll > 0 && explodeCount < limit) {
      // Roll all dice for this explosion round in parallel
      final rollFuture = roller.roll(
        numToRoll,
        finalLeft.nsides,
        '(explode #${explodeCount + 1})',
      );
      final results = await rollFuture;
      newResults.addAll(results.results);
      numToRoll = results.results.where(test).length;
      explodeCount++;
    }
    allResults.addAll(newResults);

    return RollResult(
      expression: toString(),
      opType: OpType.explode,
      ndice: finalLeft.ndice,
      nsides: finalLeft.nsides,
      results: allResults,
      metadata: RollMetadata(rolled: newResults),
      left: finalLeft,
      right: finalRight,
    );
  }
}
