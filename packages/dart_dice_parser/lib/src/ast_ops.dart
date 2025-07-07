import 'ast_core.dart';
import 'dice_roller.dart';
import 'enums.dart';
import 'roll_result.dart';
import 'rolled_die.dart';

class SortOp extends Unary {
  SortOp(super.name, super.left);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final reversed = name == 'sd';

    return RollResult(
      results: reversed ? lhs.results.sortReversed() : lhs.results.sort(),
      discarded: reversed ? lhs.discarded.sortReversed() : lhs.discarded.sort(),
      opType: OpType.sort,

      expression: toString(),
      left: lhs,
    );
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
    final lhs = await left();
    final rhs = await right();

    bool shouldCount(RolledDie rolledDie) {
      var rhsEmptyAndSimpleCount = false;
      var calculatedDefault = false;
      final target = rhs.totalOrDefault(() {
        calculatedDefault = true;
        // if missing RHS, we can make assumptions depending on operator and the dietype
        switch (name) {
          case '#':
            // example: '3d6#' should be 3. target is ignored in case statement below.
            rhsEmptyAndSimpleCount = true;
            return 0;
          case '#s' || '#cs':
            // example: '3d6#s' should match 6, or '3D66' should match 66
            return rolledDie.maxPotentialValue;
          case '#f' || '#cf':
            // generally should be 1 or whatever the minimum potential val is
            return rolledDie.minPotentialValue;
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
            // don't allow a singleVal/nvals(with 1 element) be counted as a success just because it's the min or max.
            if (calculatedDefault &&
                rolledDie.dieType.requirePotentialValues &&
                rolledDie.potentialValues.length == 1) {
              return false;
            }
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

    final scoredResults = lhs.results.where(shouldCount);

    if (countType == CountType.count) {
      // if counting, the count becomes the new result

      return RollResult(
        expression: toString(),
        opType: OpType.count,
        results: [
          RolledDie.singleVal(result: scoredResults.length, from: lhs.results),
        ],
        discarded: [...lhs.results.map(RolledDie.discard), ...lhs.discarded],
        left: lhs,
        right: rhs,
      );
    } else {
      // if counting success/failures, the results are updated w/ scoring

      final nonScoredResults = lhs.results.whereNot(shouldCount);

      return RollResult(
        expression: toString(),
        opType: OpType.count,
        results: [
          ...scoredResults.map(
            (v) => RolledDie.scoreForCountType(v, countType: countType),
          ),
          ...nonScoredResults,
        ],
        discarded: lhs.discarded,
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
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();

    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid drop operation. Missing drop target',
        toString(),
        toString().length,
      );
    });

    final Iterable<RolledDie> results;
    final Iterable<RolledDie> dropped;
    switch (name) {
      case '-<': // drop <
        results = lhs.results.where((v) => v.result >= target);
        dropped = lhs.results.where((v) => v.result < target);
      case '-<=': // drop <=
        results = lhs.results.where((v) => v.result > target);
        dropped = lhs.results.where((v) => v.result <= target);
      case '->': // drop >
        results = lhs.results.where((v) => v.result <= target);
        dropped = lhs.results.where((v) => v.result > target);
      case '->=': // drop >=
        results = lhs.results.where((v) => v.result < target);
        dropped = lhs.results.where((v) => v.result >= target);
      case '-=': // drop =
        results = lhs.results.where((v) => v.result != target);
        dropped = lhs.results.where((v) => v.result == target);
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
      results: [...results],
      discarded: [...dropped.map(RolledDie.discard), ...lhs.discarded],
      left: lhs,
      right: rhs,
    );
  }
}

/// drop operations -- drop high/low, or drop <,>,= rhs
class DropHighLowOp extends Binary {
  DropHighLowOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();
    final sorted = lhs.results.toList()..sort();
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
      results: [...results],
      discarded: [...dropped.map(RolledDie.discard), ...lhs.discarded],
      left: lhs,
      right: rhs,
    );
  }
}

/// clamp results of lhs to >,< rhs.
class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();
    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid clamp operation. Missing clamp target',
        toString(),
        toString().length,
      );
    });

    final newResults = <RolledDie>[];
    final discarded = <RolledDie>[];
    for (final d in lhs.results) {
      // TODO: add clamped flag?
      if (name == 'c>' && d.result > target) {
        discarded.add(RolledDie.copyWith(d, discarded: true, clampHigh: true));
        newResults.add(RolledDie.copyWith(d, result: target, clampHigh: true));
      } else if (name == 'c<' && d.result < target) {
        discarded.add(RolledDie.copyWith(d, discarded: true, clampLow: true));
        newResults.add(RolledDie.copyWith(d, result: target, clampLow: true));
      } else {
        newResults.add(d);
      }
    }
    return RollResult(
      expression: toString(),
      opType: OpType.clamp,
      results: newResults,
      discarded: lhs.discarded + discarded,
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
    this.limit = DiceRoller.defaultRerollLimit,
  }) {
    if (name.startsWith('ro')) {
      limit = 1;
    }
  }

  int limit;

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();

    final target = rhs.totalOrDefault(() {
      throw FormatException(
        'Invalid reroll operation. Missing reroll target',
        toString(),
        toString().length,
      );
    });

    bool shouldReroll(RolledDie rolledDie) {
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
    final discarded = <RolledDie>[];
    for (final v in lhs.results) {
      if (shouldReroll(v)) {
        RolledDie rerolled;
        var rerollCount = 0;
        do {
          rerolled = (await roller.reroll(
            v,
            '(reroll #$rerollCount)',
          )).results.first;
          rerollCount++;
        } while (shouldReroll(rerolled) && rerollCount < limit);
        discarded.add(RolledDie.copyWith(v, discarded: true, rerolled: true));
        results.add(
          RolledDie.copyWith(v, result: rerolled.result, reroll: true),
        );
      } else {
        results.add(v);
      }
    }

    return RollResult(
      expression: toString(),
      opType: OpType.reroll,
      results: results,
      discarded: lhs.discarded + discarded,
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
    this.limit = DiceRoller.defaultRerollLimit,
  }) {
    if (name.startsWith('!!o')) {
      limit = 1;
    }
  }

  int limit;

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();

    bool shouldCompound(RolledDie rolledDie) {
      final val = rolledDie.result;
      if (!rolledDie.dieType.explodable) {
        logger.finest('$rolledDie cannot compound due to dieType');
        return false;
      }
      final target = rhs.totalOrDefault(() => rolledDie.maxPotentialValue);
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
    final discarded = <RolledDie>[];
    for (final (index, rolledDie) in lhs.results.indexed) {
      if (shouldCompound(rolledDie)) {
        var sum = rolledDie.result;
        RolledDie rerolled;
        var numCompounded = 0;
        discarded.add(
          RolledDie.copyWith(rolledDie, discarded: true, compounded: true),
        );
        do {
          rerolled = (await roller.reroll(
            rolledDie,
            '(compound ind[$index] #$numCompounded)',
          )).results.first;
          discarded.add(
            RolledDie.copyWith(rerolled, discarded: true, compounded: true),
          );
          sum += rerolled.result;
          numCompounded++;
        } while (shouldCompound(rerolled) && numCompounded < limit);
        results.add(
          RolledDie.copyWith(rolledDie, result: sum, compoundedFinal: true),
        );
      } else {
        results.add(rolledDie);
      }
    }

    return RollResult(
      expression: toString(),
      opType: OpType.compound,
      results: results,
      discarded: lhs.discarded + discarded,
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
    this.limit = DiceRoller.defaultRerollLimit,
  }) {
    if (name.startsWith('!o')) {
      limit = 1;
    }
  }

  int limit;

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();

    bool shouldExplode(RolledDie rolledDie) {
      final val = rolledDie.result;
      if (!rolledDie.dieType.explodable) {
        logger.finest('$rolledDie cannot compound due to dieType');
        return false;
      }
      final target = rhs.totalOrDefault(() => rolledDie.maxPotentialValue);
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
    for (final rolledDie in lhs.results.where(shouldExplode)) {
      newResults.add(RolledDie.copyWith(rolledDie, exploded: true));
      var numExplosions = 0;
      RolledDie rerolledDie;
      do {
        rerolledDie = (await roller.reroll(
          rolledDie,
          '(explode #${numExplosions + 1})',
        )).results.first;
        numExplosions++;
        newResults.add(RolledDie.copyWith(rerolledDie, explosion: true));
      } while (shouldExplode(rerolledDie) && numExplosions < limit);
    }

    return RollResult(
      expression: toString(),
      opType: OpType.explode,
      results: [...newResults, ...lhs.results.whereNot(shouldExplode)],
      discarded: lhs.discarded,
      left: lhs,
      right: rhs,
    );
  }
}
