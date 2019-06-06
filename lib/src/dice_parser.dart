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
      ..postfix(string('dF').trim(), action(_handleSpecialDice))
      // percentile dice `Ad%`
      ..postfix(string('d%').trim(), action(_handleSpecialDice))
      // D66 dice, `AD66` aka A(1d6*10+1d6)
      ..postfix(string('D66').trim(), action(_handleSpecialDice))
      // `AdX`
      ..left(char('d').trim(), action(_handleStdDice));
    // multiplication in different group than add/subtract to enforce order of operations
    builder.group()..left(char('*').trim(), action(_handleArith));
    builder.group()
      ..left(char('+').trim(), action(_handleArith))
      ..left(char('-').trim(), action(_handleArith));
    return builder.build().end();
  }

  int _handleSpecialDice(final a, final String op) {
    var resolvedA =
        a ?? 1; // if a null, assume 1; e.g. interpret 'd10' as '1d10'
    var result = <int>[];
    switch (op) {
      case 'D66':
        result = [
          for (var i = 0; i < resolvedA; i++)
            _roller.roll(1, 6)[0] * 10 + _roller.roll(1, 6)[0]
        ];
        break;
      case 'd%':
        result = _roller.roll(resolvedA, 100);
        break;
      case 'dF':
        result = _fudgeDiceRoller.roll(resolvedA);
        break;
      default:
        throw FormatException("unknown dice operator: $op");
        break;
    }
    return sum(result);
  }

  int _handleStdDice(final a, final String op, final x) {
    return sum(_roller.roll(a ?? 1, x ?? 1));
  }

  /// Return variable as in -- if null: 0, if List: sum, otherwise variable
  int _resolveToInt(final v) {
    if (v == null) {
      return 0;
    } else if (v is Iterable<int>) {
      return sum(v);
    } else {
      return v;
    }
  }

  /// Handles arithmetic operations -- mult, add, sub
  int _handleArith(final a, final String op, final b) {
    var resolvedA = _resolveToInt(a);
    var resolvedB = _resolveToInt(b);
    switch (op) {
      case '+':
        return resolvedA + resolvedB;
        break;
      case '-':
        return resolvedA - resolvedB;
        break;
      case '*':
        return resolvedA * resolvedB;
        break;
      default:
        return 0;
    }
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
    return result.value ?? 0;
  }

  /// Evaluates given dice expression N times.
  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
