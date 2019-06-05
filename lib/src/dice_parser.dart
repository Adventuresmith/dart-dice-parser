import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';

/// A Parser/evalutator for dice notation
///
class DiceParser {
  DiceRoller _roller;
  FudgeDiceRoller _fudgeDiceRoller;
  // parser w/out actions -- makes it easier to debug output rather than evaluated
  Parser _parser;
  Parser _evaluator;

  Parser _build({attachAction = true}) {
    var action = attachAction ? (func) => func : (func) => null;
    var builder = ExpressionBuilder();
    // build groups in descending order of operations
    // * parens, ints
    // * variations of dice-expr
    // * mult
    // * add/sub
    builder.group()
      // match ints. will return null if empty
      ..primitive(digit()
          .star()
          .flatten('integer expected') // create string result of digit*
          .trim() // trim whitespace
          .map((a) => a.isNotEmpty ? int.parse(a) : null))
      // handle parens
      ..wrapper(char('(').trim(), char(')').trim(), action((l, a, r) => a));

    builder.group()
      // fudge dice `AdF`
      ..postfix(string('dF').trim(),
          action((a, op) => sum(_fudgeDiceRoller.roll(a ?? 1))))
      // percentile dice `Ad%`
      ..postfix(string('d%').trim(),
          action((a, op) => sum(_roller.roll(a ?? 1, 100))))
      // D66 dice, `AD66` aka A(1d6*10+1d6)
      ..postfix(
          string('D66').trim(),
          action((a, op) => sum([
                for (var i = 0; i < (a ?? 1); i++)
                  _roller.roll(1, 6)[0] * 10 + _roller.roll(1, 6)[0]
              ])))
      // `AdX`
      ..left(char('d').trim(),
          action((a, op, x) => sum(_roller.roll(a ?? 1, x ?? 1))));
    builder.group()
      ..left(char('*').trim(), action((a, op, b) => (a ?? 0) * (b ?? 0)));
    builder.group()
      ..left(char('+').trim(), action((a, op, b) => (a ?? 0) + (b ?? 0)))
      ..left(char('-').trim(), action((a, op, b) => (a ?? 0) - (b ?? 0)));
    return builder.build().end();
  }

  /// Constructs a dice parser, dice rollers can be injected
  DiceParser([DiceRoller r, FudgeDiceRoller rF]) {
    _roller = r ?? DiceRoller();
    _fudgeDiceRoller = rF ?? FudgeDiceRoller();

    _parser = _build(attachAction: false);
    _evaluator = _build(attachAction: true);
  }

  /// Parses the given expression and return Result
  Result<dynamic> parse(String diceStr) {
    return _parser.parse(diceStr);
  }

  /// Parses the given dice expression return evaluate-able Result.
  Result<dynamic> evaluate(String diceStr) {
    return _evaluator.parse(diceStr);
  }

  /// Evaluates the input dice expression and returns evaluated result.
  ///
  /// throws FormatException if unable to parse expression
  int roll(String diceStr) {
    var result = evaluate(diceStr);
    if (result.isFailure) {
      throw FormatException(
          "Error parsing dice expression\n" +
              "\t$diceStr\n" +
              "\t${' ' * (result.position - 1)}^-- ${result.message}",
          result.position);
    }
    return result.value;
  }

  /// Evaluates given dice expression N times.
  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
