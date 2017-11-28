import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';

import 'package:quiver/strings.dart';

class DiceParser {
  DiceRoller roller;
  Parser parser;
  Parser evaluator;

  Parser build({attachAction: true}) {
    var action = attachAction ? (func) => func : (func) => null;
    var root = failure().settable();
    var builder = new ExpressionBuilder();
    builder.group()
      ..primitive(char('(').trim().seq(root).seq(char(')').trim()).pick(1))
      ..primitive(digit().plus().flatten().trim().map((a) => int.parse(a)));
    builder.group()
      ..postfix(string('dF').trim(), action((a, op) => roller.rollFudge(a)))
      ..left(char('d').trim(), action((a, op, b) => roller.roll(a, b)));
    builder.group()
      ..left(char('*').trim(), action((a, op, b) => a * b));
    builder.group()
      ..left(char('+').trim(), action((a, op, b) => a + b))
      ..left(char('-').trim(), action((a, op, b) => a - b));
    root.set(builder.build());
    return root.end();
  }

  DiceParser([DiceRoller r]) {
    roller = r ?? new DiceRoller();

    parser = build(attachAction: false);
    evaluator = build(attachAction: true);
  }

  int roll(String diceStr) {
    if (isEmpty(diceStr)) {
      throw new FormatException("No diceStr specified");
    }

    var result = parser.parse(diceStr);
    if (result.isFailure) {
      throw new FormatException("Unable to parse '${result.buffer}' (${result.toPositionString()})", result.position);
    }
    return evaluator.parse(diceStr).value;
  }

  List<int> rollN(String diceStr, int num) {

    if (isEmpty(diceStr)) {
      throw new FormatException("No diceStr specified");
    }

    var result = parser.parse(diceStr);
    if (result.isFailure) {
      throw new FormatException("Unable to parse '${result.buffer}' (${result.toPositionString()})", result.position);
    }

    var ret = <int>[];
    for (int i=0; i < num; i++) {
      ret.add(evaluator.parse(diceStr).value);
    }

    return ret;
  }
}
