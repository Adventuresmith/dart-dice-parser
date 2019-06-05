import 'package:petitparser/petitparser.dart';

import 'package:quiver/strings.dart';
import 'dice_roller.dart';

/// A Parser/evalutator for dice notation
///
/// Supported notation:
/// * `AdX` -- roll A dice of X sides, total will be returned as value
/// * addition/subtraction/multiplication and parenthesis are allowed
///   * `2d6 + 1` -- roll two six-sided dice, sum results and add one
///   * `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
///     add that to sum of 3 100-sided die
/// * numbers must be integers, and division is is not supported.
///
/// Usage example:
///
///     int roll(String diceStr) {
///       var result = DiceParser().evaluate(diceStr);
///
///       if (result.isFailure) {
///         print("Failure:");
///         print('\t{expression}');
///         print('\t${' ' * (result.position - 1)}^-- ${result.message}');
///         return 1;
///       } else {
///         return result.value;
///       }
///     }
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
    builder.group()
      ..primitive(digit()
          .plus()
          .flatten('integer expected')
          .trim()
          .map(int.parse)) // handle integers
      ..wrapper(char('(').trim(), char(')').trim(),
          action((l, a, r) => a)); // handle parens; // handle integers
    builder.group()
      ..postfix(string('dF').trim(),
          action((a, op) => sum(_fudgeDiceRoller.roll(a)))) // fudge dice
      ..left(char('d').trim(),
          action((a, op, b) => sum(_roller.roll(a, b)))); // AdX
    builder.group()
      ..left(char('*').trim(),
          action((a, op, b) => a * b)); // left-associated mult
    builder.group()
      ..left(char('+').trim(), action((a, op, b) => a + b))
      ..left(char('-').trim(), action((a, op, b) => a - b));
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
    if (isEmpty(diceStr)) {
      throw FormatException("No diceStr specified");
    }
    return _parser.parse(diceStr);
  }

  /// Parses the given dice expression return evaluate-able Result.
  Result<dynamic> evaluate(String diceStr) {
    if (isEmpty(diceStr)) {
      throw FormatException("No diceStr specified");
    }
    return _evaluator.parse(diceStr);
  }

  /// Evaluates the input dice expression and returns evaluated result.
  ///
  /// throws FormatException if unable to parse expression
  int roll(String diceStr) {
    var result = evaluate(diceStr);
    if (result.isFailure) {
      throw FormatException(
          "Unable to parse '${result.buffer}' ($result)", result.position);
    }
    return result.value;
  }

  /// Evaluates given dice expression N times.
  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
