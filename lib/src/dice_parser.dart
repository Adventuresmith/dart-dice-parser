import "dart:collection";

import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';
import 'package:stats/stats.dart';

import 'dice_roller.dart';

/// sum an Iterable of integers
int sum(Iterable<int> l) => l.reduce((a, b) => a + b);

/// A Parser/evalutator for dice notation
///
class DiceParser {
  final Logger log = Logger('DiceParser');
  final Logger rollLogger = Logger("DiceParser.rolls");

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
      ..left(char('+').trim(), action(_handleAdd))
      ..left(char('-').trim(), action(_handleArith));
    return builder.build().end();
  }

  List<int> _handleDropHighLow(final a, final String op, final b) {
    List<int> results;
    List<int> dropped;
    var resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
    if (a is List<int>) {
      var localA = List<int>.from(a)..sort();
      switch (op) {
        case '-H': // drop high
          results = localA.reversed.skip(resolvedB).toList();
          dropped = localA.reversed.take(resolvedB).toList();
          break;
        case '-L': // drop low
          results = localA.skip(resolvedB).toList();
          dropped = localA.take(resolvedB).toList();
          break;
        default:
          log.warning(() => "unknown drop operator: $op");
          return a;
          break;
      }
    } else {
      log.warning(() =>
          "prefix to drop operator $op must be a dice roll results, not $a");
      dropped = [a];
    }
    log.finest(() =>
        "_handleDropHighLow: $a $op $b {resolved to: $a $op $resolvedB} => yielded $results (dropped: $dropped)");
    return results;
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

  /// Handles addition. If both params are lists, return aggregate. Otherwise, return [sum]
  List<int> _handleAdd(final a, final String op, final b) {
    var resolvedA = _resolveToInt(a);
    var resolvedB = _resolveToInt(b);
    var results = <int>[];
    if (a is List<int> && b is List<int>) {
      results.addAll(a);
      results.addAll(b);
    } else {
      results = [resolvedA + resolvedB];
    }
    log.finest(() =>
        "_handleAdd: $a $op $b {resolved to: $resolvedA $op $resolvedB} => yielded $results");
    return results;
  }

  /// Handles arithmetic operations -- mult, sub
  int _handleArith(final a, final String op, final b) {
    var resolvedA = _resolveToInt(a);
    var resolvedB = _resolveToInt(b);
    int result;
    switch (op) {
      case '-':
        result = resolvedA - resolvedB;
        break;
      case '*':
        result = resolvedA * resolvedB;
        break;
      default:
        result = 0;
    }
    log.finest(() =>
        "_handleArith: $a $op $b {resolved to: $resolvedA $op $resolvedB} => yielded $result");
    return result;
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

  /// Performs N rolls and outputs stats (stdev, mean, min/max, and a histogram)
  Map<String, dynamic> stats(
      {String diceStr, int numRolls = 1000, int precision = 3}) {
    var rolls = rollN(diceStr, numRolls);
    var stats = Stats.fromData(rolls);
    var results = stats.withPrecision(precision).toJson();
    var histogram = SplayTreeMap<int, int>();
    rolls.forEach((i) {
      var current = histogram[i] ?? 0;
      histogram[i] = current + 1;
    });
    results['histogram'] = histogram;
    return results;
  }

  /// Evaluates given dice expression N times.
  List<int> rollN(String diceStr, int num) {
    return [for (var i = 0; i < num; i++) roll(diceStr)];
  }
}
