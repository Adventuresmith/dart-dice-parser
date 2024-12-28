import 'package:petitparser/petitparser.dart';

import 'ast.dart';
import 'dice_expression.dart';
import 'dice_roller.dart';

Parser<DiceExpression> parserBuilder(DiceRoller roller) {
  final builder = ExpressionBuilder<DiceExpression>();
  // numbers
  builder.primitive(
    digit().star().flatten('integer expected').trim().map(SimpleValue.new),
  );
  // parens
  builder.group().wrapper(
        char('(').trim(),
        char(')').trim(),
        (left, value, right) => value,
      );
  // special dice handling need to have higher precedence than 'd'
  builder.group()
    ..postfix(
      string('dF').trim(),
      (a, op) => FudgeDice(op, a, roller),
    )
    ..postfix(
      string('D66').trim(),
      (a, op) => D66Dice(op, a, roller),
    )
    ..postfix(
      string('d%').trim(),
      (a, op) => PercentDice(op, a, roller),
    )
    ..postfix(
      seq4(
        char('d').trim(),
        char('[').trim(),
        (char('-').optional() & digit().plus())
            .flatten()
            .plusSeparated(char(',').trim())
            .trim(),
        char(']').trim(),
      ),
      (a, op) => CSVDice(op.toString(), a, roller, op.$3),
    );
  builder.group().left(
        char('d').trim(),
        (a, op, b) => StdDice(op, a, b, roller),
      );

  // compounding dice (has to be in separate group from exploding)
  builder.group().left(
        (string('!!') &
                pattern('oO').optional() &
                pattern('<>').optional() &
                char('=').optional())
            .flatten()
            .trim(),
        (a, op, b) => CompoundingDice(op.toLowerCase(), a, b, roller),
      );
  builder.group()
    // reroll & reroll once
    ..left(
      (pattern('rR') &
              pattern('oO').optional() &
              pattern('<>').optional() &
              char('=').optional())
          .flatten()
          .trim(),
      (a, op, b) => RerollDice(op.toLowerCase(), a, b, roller),
    )
    // exploding
    ..left(
      (char('!') &
              pattern('oO').optional() &
              pattern('<>').optional() &
              char('=').optional())
          .flatten()
          .trim(),
      (a, op, b) => ExplodingDice(op.toLowerCase(), a, b, roller),
    )
    // cap/clamp >,<
    ..left(
      (pattern('cC') & pattern('<>').optional()).flatten().trim(),
      (a, op, b) => ClampOp(op.toLowerCase(), a, b),
    )
    // drop >=,<=,>,<
    ..left(
      (char('-') & pattern('<>') & char('=').optional()).flatten().trim(),
      (a, op, b) => DropOp(op.toLowerCase(), a, b),
    )
    ..left(
      (string('-=')).flatten().trim(),
      (a, op, b) => DropOp(op.toLowerCase(), a, b),
    )
    // drop(-) low, high
    ..left(
      (char('-') & pattern('LlHh')).flatten().trim(),
      (a, op, b) => DropHighLowOp(op.toLowerCase(), a, b),
    )
    // keep low/high
    ..left(
      (pattern('Kk') & pattern('LlHh').optional()).flatten().trim(),
      (a, op, b) => DropHighLowOp(op.toLowerCase(), a, b),
    );

  builder.group().left(char('*').trim(), (a, op, b) => MultiplyOp(op, a, b));
  builder.group()
    ..left(char('+').trim(), (a, op, b) => AddOp(op, a, b))
    ..left(char('-').trim(), (a, op, b) => SubOp(op, a, b));
  // count >=, <=, <, >, =,
  // #s, #cs, #f, #cf -- count (critical) successes / failures
  builder.group().left(
        (char('#') &
                char('c').optional() &
                pattern('sf').optional() &
                pattern('<>').optional() &
                char('=').optional())
            .flatten()
            .trim(),
        (a, op, b) => CountOp(op.toLowerCase(), a, b),
      );
  return builder.build().end();
}
