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
    );
  builder.group().left(
        char('d').trim(),
        (a, op, b) => StdDice(op.toString(), a, b, roller),
      );

  builder.group().postfix(
        string('!!').trim(),
        (a, op) => CompoundingDice(op.toString(), a, roller),
      );
  builder.group().postfix(
        char('!').trim(),
        (a, op) => ExplodingDice(op.toString(), a, roller),
      );
  builder.group()
    // cap/clamp >=,<=
    ..left(
      (pattern('cC') & pattern('<>').optional() & char('=').optional())
          .flatten()
          .trim(),
      (a, op, b) => ClampOp(op.toString().toUpperCase(), a, b),
    )
    // drop >=,<=,>,<
    ..left(
      (char('-') & pattern('<>') & char('=').optional()).flatten().trim(),
      (a, op, b) => DropOp(op.toString().toUpperCase(), a, b),
    )
    ..left(
      (string('-=')).flatten().trim(),
      (a, op, b) => DropOp(op.toString().toUpperCase(), a, b),
    )
    // drop(-) low, high
    ..left(
      (char('-') & pattern('LlHh')).flatten().trim(),
      (a, op, b) => DropHighLowOp(op.toString().toUpperCase(), a, b),
    )
    // keep low/high
    ..left(
      (pattern('Kk') & pattern('LlHh').optional()).flatten().trim(),
      (a, op, b) => DropHighLowOp(op.toString().toUpperCase(), a, b),
    );

  // count >=, <=, <, >, =, #
  builder.group().left(
        (char('#') & pattern('<>').optional() & char('=').optional())
            .flatten()
            .trim(),
        (a, op, b) => CountOp(op.toString(), a, b),
      );
  builder
      .group()
      .left(char('*').trim(), (a, op, b) => MultiplyOp(op.toString(), a, b));
  builder.group()
    ..left(char('+').trim(), (a, op, b) => AddOp(op.toString(), a, b))
    ..left(char('-').trim(), (a, op, b) => SubOp(op.toString(), a, b));
  return builder.build().end();
}
