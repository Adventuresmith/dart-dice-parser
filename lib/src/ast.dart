import 'package:collection/collection.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/utils.dart';
import 'package:petitparser/petitparser.dart';

/// An abstract expression that can be evaluated.
mixin DiceExprMixin {
  /// each operation is callable (when we call the parsed string, this is the method that'll be used)
  List<int> call();
}

/// A value expression.
class Value with DiceExprMixin {
  Value(this.value);

  final int value;

  @override
  List<int> call() => [value];

  @override
  String toString() => '{$value}';
}

abstract class DiceOp with DiceExprMixin, LoggingMixin {
  List<int> op();

  @override
  List<int> call() {
    final results = op();
    log.finer(() => "$this => $results");
    return results;
  }
}

// base class for unary operations
abstract class Unary extends DiceOp {
  Unary(this.name, this.left);
  final String name;
  final DiceExprMixin left;

  @override
  String toString() => '{$left$name}';
}

abstract class Binary extends DiceOp {
  Binary(this.name, this.left, this.right);
  final String name;
  final DiceExprMixin left;
  final DiceExprMixin right;

  @override
  String toString() => '{$left$name$right}';
}

class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = resolveToInt(left());
    final rhs = resolveToInt(right());
    return [lhs * rhs];
  }
}

class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    return left() + right();
  }
}

class CountEqual extends Unary {
  CountEqual(super.name, super.left);

  @override
  List<int> op() {
    final lhs = left();
    return [lhs.length];
  }
}

class CountOp extends Binary {
  CountOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = left();
    final rhs = resolveToInt(right(), 1); // if missing, assume '1'
    switch (name) {
      case "#>": // how many results on lhs are greater than rhs?
        return [lhs.where((v) => v > rhs).length];
      case "#<": // how many results on lhs are less than rhs?
        return [lhs.where((v) => v < rhs).length];
      case "#=": // how many results on lhs are equal to rhs?
        return [lhs.where((v) => v > rhs).length];
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
  }
}

class DropOp extends Binary {
  DropOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = left();
    final rhs = resolveToInt(right(), 1); // if missing, assume '1'
    var results = <int>[];
    var dropped = <int>[];
    switch (name.toUpperCase()) {
      case '-<': // drop less than
        results = lhs.where((v) => v >= rhs).toList();
        dropped = lhs.where((v) => v < rhs).toList();
        break;
      case '->': // drop greater than
        results = lhs.where((v) => v <= rhs).toList();
        dropped = lhs.where((v) => v > rhs).toList();
        break;
      case '-=': // drop equal
        results = lhs.where((v) => v != rhs).toList();
        dropped = lhs.where((v) => v == rhs).toList();
        break;
      case '-H': // drop high
        final sorted = lhs..sort();
        results = sorted.reversed.skip(rhs).toList();
        dropped = sorted.reversed.take(rhs).toList();
        break;
      case '-L': // drop low
        final sorted = lhs..sort();
        results = sorted.skip(rhs).toList();
        dropped = sorted.take(rhs).toList();
        break;
      default:
        throw FormatException("unknown roll modifier '$name' in $this");
    }
    return results;
  }
}

class ClampOp extends Binary {
  ClampOp(super.name, super.left, super.right);

  @override
  List<int> op() {
    final lhs = left();
    final rhs = resolveToInt(right(), 1); // if missing, assume '1'
    switch (name.toUpperCase()) {
      case "C>": // change any value greater than rhs to rhs
        return lhs.map((v) {
          if (v > rhs) {
            return rhs;
          } else {
            return v;
          }
        }).toList();
      case "C<": // change any value less than rhs to rhs
        return lhs.map((v) {
          if (v < rhs) {
            return rhs;
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

class FudgeDice extends UnaryDice {
  FudgeDice(super.name, super.left, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left(), 1);
    return roller.rollFudge(ndice);
  }
}

class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left(), 1);
    return roller.roll(ndice, 100);
  }
}

class D66Dice extends UnaryDice {
  D66Dice(super.name, super.left, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left(), 1);
    return [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6)[0] * 10 + roller.roll(1, 6)[0]
    ];
  }
}

class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  List<int> op() {
    final ndice = resolveToInt(left(), 1);
    final nsides = resolveToInt(right(), 1);
    return roller.roll(ndice, nsides);
  }
}

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
    final ndice = resolveToInt(left(), 1);
    final nsides = resolveToInt(right(), 1);
    return roller.rollWithExplode(
      ndice: ndice,
      nsides: nsides,
      explode: true,
      explodeLimit: explodeLimit,
    );
  }
}

/// if v is int, return v. if v is list, sum v.
/// anything else, return defaultVal
// TODO: do we need this method at all? In new structure, everything's a int-list
int resolveToInt(dynamic v, [int defaultVal = 0]) {
  if (v is Iterable<int>) {
    return v.sum;
  } else if (v is int) {
    return v;
  } else {
    return defaultVal;
  }
}

DiceExprMixin _createValue(String value) =>
    Value(value.isNotEmpty ? int.parse(value) : 0);

final diceParserFactory = () {
  final roller = DiceRoller();
  final builder = ExpressionBuilder<DiceExprMixin>();
  builder.group()
    ..primitive(
      digit().star().flatten('integer expected').trim().map(_createValue),
    )
    ..wrapper(
      char('(').trim(),
      char(')').trim(),
      (left, value, right) => value,
    );
  // d!! needs higher precedence than d!
  builder.group().left(
        string('d!!').trim(),
        (a, op, b) => ExplodeDice('d!!', a, b, roller, 1),
      );
  builder.group()
    ..postfix(string('dF').trim(), (a, operator) => FudgeDice('dF', a, roller))
    ..postfix(
      string('D66').trim(),
      (a, operator) => D66Dice('D66', a, roller),
    )
    ..postfix(
      string('d%').trim(),
      (a, operator) => PercentDice('d%', a, roller),
    )
    ..left(string('d!').trim(), (a, op, b) => ExplodeDice('d!', a, b, roller));
  builder
      .group()
      .left(char('d').trim(), (a, op, b) => StdDice('d', a, b, roller));
  builder.group()
    // cap/clamp
    ..left(string('C>').trim(), (a, op, b) => ClampOp('C>', a, b))
    ..left(string('c>').trim(), (a, op, b) => ClampOp('C>', a, b))
    ..left(string('C<').trim(), (a, op, b) => ClampOp('C<', a, b))
    ..left(string('c<').trim(), (a, op, b) => ClampOp('C<', a, b))
    // drop
    ..left(string('->').trim(), (a, op, b) => DropOp('->', a, b))
    ..left(string('-<').trim(), (a, op, b) => DropOp('-<', a, b))
    ..left(string('-=').trim(), (a, op, b) => DropOp('-=', a, b))
    ..left(string('-L').trim(), (a, op, b) => DropOp('-L', a, b))
    ..left(string('-l').trim(), (a, op, b) => DropOp('-L', a, b))
    ..left(string('-H').trim(), (a, op, b) => DropOp('-H', a, b))
    ..left(string('-h').trim(), (a, op, b) => DropOp('-H', a, b));
  builder.group()
    // count
    ..left(string('#>').trim(), (a, op, b) => CountOp('#>', a, b))
    ..left(string('#<').trim(), (a, op, b) => CountOp('#<', a, b))
    ..left(string('#=').trim(), (a, op, b) => CountOp('#<', a, b));
  builder.group().postfix(char('#').trim(), (a, op) => CountEqual('#', a));
  builder.group().left(char('*').trim(), (a, op, b) => MultiplyOp('*', a, b));
  builder.group().left(char('+').trim(), (a, op, b) => AddOp('+', a, b));
  return builder.build().end();
}();
