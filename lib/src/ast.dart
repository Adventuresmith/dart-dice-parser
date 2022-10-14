import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/utils.dart';
import 'package:petitparser/petitparser.dart';

/// An abstract expression that can be evaluated.
mixin DiceExprMixin {
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

class Multiply with DiceExprMixin, LoggingMixin {
  Multiply(this.name, this.left, this.right);

  final String name;
  final DiceExprMixin left;
  final DiceExprMixin right;

  @override
  List<int> call() {
    final lhs = resolveToInt(left());
    final rhs = resolveToInt(right());
    final results = [lhs * rhs];
    log.finer(() => "$this => $results");
    return results;
  }

  @override
  String toString() => '{$left$name$right}';
}

abstract class UnaryDice with DiceExprMixin, LoggingMixin {
  UnaryDice(this.name, this.left, this.roller);

  final String name;
  final DiceExprMixin left;
  final DiceRoller roller;

  @override
  List<int> call() {
    final ndice = resolveToInt(left(), 1);
    final results = roll(ndice);
    log.finer(() => "$this => $results");
    return results;
  }

  List<int> roll(int ndice);

  @override
  String toString() => '{$left$name}';
}

abstract class BinaryDice with DiceExprMixin, LoggingMixin {
  BinaryDice(this.name, this.left, this.right, this.roller);

  final String name;
  final DiceExprMixin left;
  final DiceExprMixin right;
  final DiceRoller roller;

  List<int> roll(int ndice, int nsides);

  @override
  List<int> call() {
    final ndice = resolveToInt(left(), 1);
    final nsides = resolveToInt(right(), 1);
    final results = roll(ndice, nsides);
    log.finer(() => "$this => $results");
    return results;
  }

  @override
  String toString() => '{$left$name$right}';
}

class FudgeDice extends UnaryDice {
  FudgeDice(super.name, super.left, super.roller);

  @override
  List<int> roll(int ndice) {
    return roller.rollFudge(ndice);
  }
}

class PercentDice extends UnaryDice {
  PercentDice(super.name, super.left, super.roller);

  @override
  List<int> roll(int ndice) {
    return roller.roll(ndice, 100);
  }
}

class D66Dice extends UnaryDice {
  D66Dice(super.name, super.left, super.roller);

  @override
  List<int> roll(int ndice) {
    return [
      for (var i = 0; i < ndice; i++)
        roller.roll(1, 6)[0] * 10 + roller.roll(1, 6)[0]
    ];
  }
}

class StdDice extends BinaryDice {
  StdDice(super.name, super.left, super.right, super.roller);

  @override
  List<int> roll(int ndice, int nsides) {
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
  List<int> roll(int ndice, int nsides) {
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
int resolveToInt(v, [int defaultVal = 0]) {
  if (v is Iterable<int>) {
    return v.sum;
  } else if (v is int) {
    return v;
  } else {
    return defaultVal;
  }
}

DiceExprMixin _createValue(String value) => Value(int.parse(value));

final diceParserFactory = () {
  final roller = DiceRoller();
  final builder = ExpressionBuilder<DiceExprMixin>();
  builder.group()
    ..primitive(
      digit().plus().flatten('integer expected').trim().map(_createValue),
    )
    ..wrapper(
        char('(').trim(), char(')').trim(), (left, value, right) => value);
  builder.group().left(
        string('d!!').trim(),
        (a, op, b) => ExplodeDice('d!!', a, b, roller, 1),
      );
  builder.group()
    ..postfix(string('dF').trim(), (a, operator) => FudgeDice('dF', a, roller))
    ..postfix(
      string('D66').trim(),
      (a, operator) => FudgeDice('D66', a, roller),
    )
    ..postfix(string('d%').trim(), (a, operator) => FudgeDice('d%', a, roller))
    ..left(string('d!').trim(), (a, op, b) => ExplodeDice('d!', a, b, roller));
  builder
      .group()
      .left(char('d').trim(), (a, op, b) => StdDice('d', a, b, roller));
  builder.group().left(char('*').trim(), (a, op, b) => Multiply('*', a, b));
  builder.group().left(char('+').trim(), (a, op, b) => Multiply('+', a, b));
  return builder.build().end();
}();
