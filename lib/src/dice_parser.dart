import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';

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
          action((a, op) => fudgeDiceRoller.roll(a).total())) // fudge dice
      ..left(char('d').trim(),
          action((a, op, b) => roller.roll(a, b).total())); // AdX
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
    if (diceStr == null || diceStr.isEmpty) {
      throw new FormatException("No diceStr specified");
    }
    var result = parser.parse(diceStr);
    if (result.isFailure) {
      throw new FormatException(
          "Unable to parse '${result.buffer}' (${result})", result.position);
    }
    return result;
  }

  /// parse the given dice expression for evaluation.
  Result<dynamic> evaluate(String diceStr) {
    if (diceStr == null || diceStr.isEmpty) {
      throw new FormatException("No diceStr specified");
    }
    var result = evaluator.parse(diceStr);
    if (result.isFailure) {
      throw new FormatException(
          "Unable to parse '${result.buffer}' (${result})", result.position);
    }
    return result;
  }

  int roll(String diceStr) => evaluate(diceStr).value;

  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
