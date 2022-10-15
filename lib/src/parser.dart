import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/ast.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/stats.dart';
import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';

final Logger _log = Logger("parser");

extension DiceExpressionExtension on DiceExpression {
  /// rolls the dice expression
  int roll() {
    final result = this();
    final sum = result.sum;
    _log.fine(() => "$this => $result => $sum");
    return sum;
  }

  /// Lazy iterable of rolling N times. Results returned as stream.
  Stream<int> rollN(int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll();
    }
  }

  /// Performs N rolls and outputs stats (stddev, mean, min/max, and a histogram)
  Future<Map<String, dynamic>> stats({
    int num = 10000,
    int precision = 3,
  }) async {
    final stats = StatsCollector();

    await for (final r in rollN(num)) {
      stats.update(r);
    }
    return stats.asMap();
  }
}

class DiceExpressionFactory {
  DiceExpressionFactory([Random? random]) : roller = DiceRoller(random);
  final DiceRoller roller;

  /// parse the given input into a DiceExpression
  /// throws format exception if invalid
  DiceExpression create(String input) {
    final result = _parserBuilder().parse(input);
    if (result.isFailure) {
      throw FormatException(
          "Error parsing dice expression", input, result.position);
    }
    return result.value;
  }

  Parser<DiceExpression> _parserBuilder() {
    final builder = ExpressionBuilder<DiceExpression>();
    builder.group()
      ..primitive(
        digit().star().flatten('integer expected').trim().map((v) => Value(v)),
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
      ..postfix(
          string('dF').trim(), (a, operator) => FudgeDice('dF', a, roller))
      ..postfix(
        string('D66').trim(),
        (a, operator) => D66Dice('D66', a, roller),
      )
      ..postfix(
        string('d%').trim(),
        (a, operator) => PercentDice('d%', a, roller),
      )
      ..left(
          string('d!').trim(), (a, op, b) => ExplodeDice('d!', a, b, roller));
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
    builder.group().postfix(char('#').trim(), (a, op) => CountResults('#', a));
    builder.group().left(char('*').trim(), (a, op, b) => MultiplyOp('*', a, b));
    builder.group().left(char('+').trim(), (a, op, b) => AddOp('+', a, b));
    return builder.build().end();
  }
}
