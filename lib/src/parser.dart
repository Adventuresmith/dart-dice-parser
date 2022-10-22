import 'package:dart_dice_parser/src/ast.dart';
import 'package:dart_dice_parser/src/dice_expression.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:petitparser/petitparser.dart';

Parser<DiceExpression> parserBuilder(DiceRoller roller) {
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
        (a, op, b) => ExplodeDice(op.toString(), a, b, roller, 1),
      );
  // special dice handling need to have higher precedence than 'd'
  builder.group()
    ..postfix(
      string('dF').trim(),
      (a, op) => FudgeDice(op.toString(), a, roller),
    )
    ..postfix(
      string('D66').trim(),
      (a, op) => D66Dice(op.toString(), a, roller),
    )
    ..postfix(
      string('d%').trim(),
      (a, op) => PercentDice(op.toString(), a, roller),
    )
    ..left(
      string('d!').trim(),
      (a, op, b) => ExplodeDice(op.toString(), a, b, roller),
    );
  builder.group().left(
      char('d').trim(), (a, op, b) => StdDice(op.toString(), a, b, roller));
  builder.group()
    // cap/clamp
    ..left(string('C>').trim(),
        (a, op, b) => ClampOp(op.toString().toUpperCase(), a, b))
    ..left(string('c>').trim(),
        (a, op, b) => ClampOp(op.toString().toUpperCase(), a, b))
    ..left(string('C<').trim(),
        (a, op, b) => ClampOp(op.toString().toUpperCase(), a, b))
    ..left(string('c<').trim(),
        (a, op, b) => ClampOp(op.toString().toUpperCase(), a, b))
    // drop
    ..left(string('->').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-<').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-=').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-L').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-l').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-H').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b))
    ..left(string('-h').trim(),
        (a, op, b) => DropOp(op.toString().toUpperCase(), a, b));
  builder.group()
    // count
    ..left(string('#>').trim(), (a, op, b) => CountOp(op.toString(), a, b))
    ..left(string('#<').trim(), (a, op, b) => CountOp(op.toString(), a, b))
    ..left(string('#=').trim(), (a, op, b) => CountOp(op.toString(), a, b));
  builder
      .group()
      .postfix(char('#').trim(), (a, op) => CountResults(op.toString(), a));
  builder
      .group()
      .left(char('*').trim(), (a, op, b) => MultiplyOp(op.toString(), a, b));
  builder.group()
    ..left(char('+').trim(), (a, op, b) => AddOp(op.toString(), a, b))
    ..left(char('-').trim(), (a, op, b) => SubOp(op.toString(), a, b));
  return builder.build().end();
}
