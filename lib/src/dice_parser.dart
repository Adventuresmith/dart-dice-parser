import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';
import 'package:quiver/strings.dart';

/// Parser/evalutator for dice notation
///
///
class DiceParser {
  DiceRoller roller;
  FudgeDiceRoller fudgeDiceRoller;
  // parser w/out actions -- makes it easier to debug output rather than evaluated
  Parser parser;
  Parser evaluator;

  Parser build({attachAction: true}) {
    var action = attachAction ? (func) => func : (func) => null;
    var builder = new ExpressionBuilder();
    builder.group()
      ..primitive(digit()
          .plus()
          .flatten('integer expected')
          .trim()
          .map((a) => int.parse(a))) // handle integers
      ..wrapper(char('(').trim(), char(')').trim(),
          action((l, a, r) => a)); // handle parens; // handle integers
    builder.group()
      ..postfix(string('dF').trim(),
          action((a, op) => sum(fudgeDiceRoller.roll(a)))) // fudge dice
      ..left(char('d').trim(),
          action((a, op, b) => sum(roller.roll(a, b)))); // AdX
    builder.group()
      ..left(char('*').trim(),
          action((a, op, b) => a * b)); // left-associated mult
    builder.group()
      ..left(char('+').trim(), action((a, op, b) => a + b))
      ..left(char('-').trim(), action((a, op, b) => a - b));
    return builder.build().end();
  }

  DiceParser([DiceRoller r, FudgeDiceRoller rF]) {
    roller = r ?? new DiceRoller();
    fudgeDiceRoller = rF ?? new FudgeDiceRoller();

    parser = build(attachAction: false);
    evaluator = build(attachAction: true);
  }

  /// parse the given expression and return the result (NOTE: this cannot be evaluated)
  Result<dynamic> parse(String diceStr) {
    if (isEmpty(diceStr)) {
      throw new FormatException("No diceStr specified");
    }
    return parser.parse(diceStr);
  }

  /// parse the given dice expression for evaluation.
  Result<dynamic> evaluate(String diceStr) {
    if (isEmpty(diceStr)) {
      throw new FormatException("No diceStr specified");
    }
    return evaluator.parse(diceStr);
  }

  int roll(String diceStr) {
    var result = evaluate(diceStr);
    if (result.isFailure) {
      throw new FormatException(
          "Unable to parse '${result.buffer}' (${result})", result.position);
    }
    return result.value;
  }

  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
