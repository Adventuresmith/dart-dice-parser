import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';

/// sum an Iterable of integers
int sum(Iterable<int> l) => l.reduce((a, b) => a + b);

/// A Parser/evalutator for dice notation
///
class DiceParser {
  final Logger log = Logger('DiceParser');

  DiceRoller _roller;
  // parser w/out actions -- makes it easier to debug output rather than evaluated
  Parser _parser;
  Parser _evaluator;

  /// Constructs a dice parser, dice roller injectible for mocking random
  DiceParser({DiceRoller diceRoller}) {
    _roller = diceRoller ?? DiceRoller();

    _parser = _build(attachAction: false);
    _evaluator = _build(attachAction: true);
  }

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
    // before arithmetic, but after dice grouping... handle dice re-rolls/variation
    //   AdXHN -- roll AdX, drop N highest
    //   AdXLN -- roll AdX, drop N lowest
    builder.group()
      ..left(string('-H').trim(), action(_handleDropHighLow))
      ..left(string('-L').trim(), action(_handleDropHighLow));
    // multiplication in different group than add/subtract to enforce order of operations
    builder.group()..left(char('*').trim(), action(_handleArith));
    builder.group()
      ..left(char('+').trim(), action(_handleArith))
      ..left(char('-').trim(), action(_handleArith));
    return builder.build().end();
  }

  List<int> _handleDropHighLow(final a, final String op, final b) {
    var resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
    if (a is List<int>) {
      List<int> results;
      var localA = List<int>.from(a)..sort();
      switch (op) {
        case '-H': // drop high
          results = localA.reversed.skip(resolvedB).toList();
          break;
        case '-L': // drop low
          results = localA.skip(resolvedB).toList();
          break;
        default:
          throw FormatException("unknown drop operator: $op");
          break;
      }
      log.finest(() =>
          "_handleDropHighLow: $a $op $b {resolved to: $a $op $resolvedB} => yielded $results");
      return results;
    }
    throw FormatException("unknown drop type: $a $op $b");
  }

  List<int> _handleStdDice(final a, final String op, final x) {
    var resolvedA = _resolveToInt(a, 1);
    var resolvedX = _resolveToInt(x, 1);
    var results = _roller.roll(resolvedA, resolvedX);
    log.finest(() =>
        "_handleStdDice: $a $op $x {resolved to: $resolvedA $op $resolvedX} => yielded $results");
    return results;
  }

  List<int> _handleSpecialDice(final a, final String op) {
    // if a null, assume 1; e.g. interpret 'd10' as '1d10'
    // if it's a list (i.e. a dice roll), sum the results
    var resolvedA = _resolveToInt(a, 1);
    var results = <int>[];
    switch (op) {
      case 'D66':
        results = [
          for (var i = 0; i < resolvedA; i++)
            _roller.roll(1, 6)[0] * 10 + _roller.roll(1, 6)[0]
        ];
        break;
      case 'd%':
        results = _roller.roll(resolvedA, 100);
        break;
      case 'dF':
        results = _roller.rollFudge(resolvedA);
        break;
      default:
        throw FormatException("unknown dice operator: $op");
        break;
    }
    log.finest(() =>
        "_handleSpecialDice: $a $op {resolved to: $resolvedA $op} => yielded $results");
    return results;
  }

  /// Return variable as in -- if null: return default, if List: sum
  int _resolveToInt(final v, [final defaultVal = 0]) {
    if (v == null) {
      return defaultVal;
    } else if (v is Iterable<int>) {
      if (v.length == 0) {
        return 0;
      } else {
        return sum(v);
      }
    } else {
      return v;
    }
  }

  /// Handles arithmetic operations -- mult, add, sub
  int _handleArith(final a, final String op, final b) {
    var resolvedA = _resolveToInt(a);
    var resolvedB = _resolveToInt(b);
    log.finest(() =>
        "_handleArith: $a $op $b {resolved to: $resolvedA $op $resolvedB}");
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
      throw FormatException("""
Error parsing dice expression
    $diceStr
    ${' ' * (result.position - 1)}^-- ${result.message}
        """, result.position);
    }
    return _resolveToInt(result.value);
  }

  /// Evaluates given dice expression N times.
  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
