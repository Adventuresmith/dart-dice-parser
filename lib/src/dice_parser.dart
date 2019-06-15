import "dart:collection";
import "dart:math";

import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';

/// sum an Iterable of integers
int sum(Iterable<int> l) => l.reduce((a, b) => a + b);

/// A Parser/evalutator for dice notation
///
class DiceParser {
  final Logger _log = Logger('DiceParser');

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
    var root = failure().settable();
    // build groups in descending order of operations
    // * parens, ints
    // * variations of dice-expr
    // * mult
    // * add/sub
    builder.group()
      // handle parens TODO: need petitparser 2.3.0
      //..wrapper(char('(').trim(), char(')').trim(), action((l, a, r) => a));
      ..primitive(char('(').trim().seq(root).seq(char(')').trim()).pick(1))
      // match ints. will return null if empty
      ..primitive(digit()
          .star()
          .flatten('integer expected') // create string result of digit*
          .trim() // trim whitespace
          .map((a) => a.isNotEmpty ? int.parse(a) : null));
    // exploding dice need to be higher precendence (before 'd')
    builder.group()..left(string('d!!').trim(), action(_handleStdDice));
    builder.group()..left(string('d!').trim(), action(_handleStdDice));
    builder.group()
      // fudge dice `AdF`
      ..postfix(string('dF').trim(), action(_handleSpecialDice))
      // percentile dice `Ad%`
      ..postfix(string('d%').trim(), action(_handleSpecialDice))
      // D66 dice, `AD66` aka A(1d6*10+1d6)
      ..postfix(string('D66').trim(), action(_handleSpecialDice))
      // `AdX`
      ..left(char('d').trim(), action(_handleStdDice));
    // before arithmetic, but after dice grouping... handle dice re-rolls, mods, drops
    builder.group()
      // cap/clamp  C> or C<
      ..left(string('C>').trim(), action(_handleRollResultModifiers))
      ..left(string('C<').trim(), action(_handleRollResultModifiers))
      ..left(string('c>').trim(), action(_handleRollResultModifiers))
      ..left(string('c<').trim(), action(_handleRollResultModifiers))
      // drop
      ..left(string('-<').trim(), action(_handleRollResultModifiers))
      ..left(string('->').trim(), action(_handleRollResultModifiers))
      ..left(string('-=').trim(), action(_handleRollResultModifiers))
      ..left(string('-L').trim(), action(_handleRollResultModifiers))
      ..left(string('-H').trim(), action(_handleRollResultModifiers))
      ..left(string('-l').trim(), action(_handleRollResultModifiers))
      ..left(string('-h').trim(), action(_handleRollResultModifiers));
    builder.group()
      // count
      ..left(string('#>').trim(), action(_handleRollResultOperation))
      ..left(string('#<').trim(), action(_handleRollResultOperation))
      ..left(string('#=').trim(), action(_handleRollResultOperation));
    builder.group()
      // count total -- needs to be lower precedence than the other counters
      ..postfix(string('#').trim(),
          action((a, op) => _handleRollResultOperation(a, op, null)));
    // multiplication in different group than add/subtract to enforce order of operations
    builder.group()..left(char('*').trim(), action(_handleArith));
    builder.group()
      ..left(char('+').trim(), action(_handleAdd))
      ..left(char('-').trim(), action(_handleArith));
    //return builder.build().end();

    root.set(builder.build());
    return root.end();
  }

  int _handleRollResultOperation(final a, final String op, final b) {
    int result;
    var resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
    if (a is List<int>) {
      switch (op) {
        case '#>': // count greater than
          result = a.where((v) => v > resolvedB).length;
          break;
        case '#<': // count less than
          result = a.where((v) => v < resolvedB).length;
          break;
        case '#=': // count equal
          result = a.where((v) => v == resolvedB).length;
          break;
        case '#': // count
          result = a.length;
          break;
        default:
          // throw exception, this is a dev-time error
          throw FormatException(
              "unknown roll modifier: $a$op${b ?? resolvedB}");
          break;
      }
    } else {
      // log warning, this is a user-facing error
      _log.warning(() =>
          "prefix to roll operation $op must be a dice roll results, not $a");
      result = 0;
    }
    _log.finer(() => "$a$op$resolvedB => $result");
    return result;
  }

  List<int> _handleRollResultModifiers(final a, final String op, final b) {
    List<int> results;
    List<int> dropped;
    var resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
    if (a is List<int>) {
      var localA = a.toList()..sort();
      switch (op.toUpperCase()) {
        case '-H': // drop high
          results = localA.reversed.skip(resolvedB).toList();
          dropped = localA.reversed.take(resolvedB).toList();
          break;
        case '-L': // drop low
          results = localA.skip(resolvedB).toList();
          dropped = localA.take(resolvedB).toList();
          break;
        case '-<': // drop less than
          results = localA.where((v) => v >= resolvedB).toList();
          dropped = localA.where((v) => v < resolvedB).toList();
          break;
        case '->': // drop greater than
          results = localA.where((v) => v <= resolvedB).toList();
          dropped = localA.where((v) => v > resolvedB).toList();
          break;
        case '-=': // drop equal
          results = localA.where((v) => v != resolvedB).toList();
          dropped = localA.where((v) => v == resolvedB).toList();
          break;
        case 'C<': // change any value less than B to B
          results = a.map((v) {
            if (v < resolvedB) {
              return resolvedB;
            } else {
              return v;
            }
          }).toList();
          break;
        case 'C>': // change any value greater than B to B
          results = a.map((v) {
            if (v > resolvedB) {
              return resolvedB;
            } else {
              return v;
            }
          }).toList();
          break;
        default:
          throw FormatException(
              "unknown roll modifier: $a$op${b ?? resolvedB}");
          break;
      }
    } else {
      _log.warning(() =>
          "prefix to roll modifier $op must be a dice roll results, not $a");
      results = [a];
    }
    _log.finer(() =>
        "$a$op${b ?? resolvedB} => $results ${dropped != null ? '(dropped:' + dropped.toString() + ')' : '[]'}");
    return results;
  }

  List<int> _handleStdDice(final a, final String op, final x) {
    var resolvedA = _resolveToInt(a, 1);
    var resolvedX = _resolveToInt(x, 1);

    var results = <int>[];
    switch (op) {
      case 'd':
        results = _roller.roll(resolvedA, resolvedX);
        break;
      case "d!":
        results = _roller.rollWithExplode(
            ndice: resolvedA, nsides: resolvedX, explode: true);
        break;
      case 'd!!':
        results = _roller.rollWithExplode(
            ndice: resolvedA,
            nsides: resolvedX,
            explode: true,
            explodeLimit: 1);
        break;
    }

    _log.finer(() => "${a ?? resolvedA}$op${x ?? resolvedX} => $results");
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
        results = a;
        _log.warning("unknown dice operator: $a$op");
        break;
    }
    _log.finer(() => "${a ?? resolvedA}$op => $results");
    return results;
  }

  /// Return variable as in -- if null: return default, if List: sum
  int _resolveToInt(final v, [final defaultVal = 0]) {
    if (v == null) {
      return defaultVal;
    } else if (v is Iterable<int>) {
      if (v.isEmpty) {
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
    _log.finer(() => "${a ?? resolvedA}$op${b ?? resolvedB} => $results");
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
    _log.finer(() => "${a ?? resolvedA}$op${b ?? resolvedB} => $result");
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
  Future<Map<String, dynamic>> stats(
      {String diceStr, int numRolls = 10000, int precision = 3}) async {
    var stats = Statsimator();

    await for (final r in rollN(diceStr, numRolls)) {
      stats.update(r);
    }
    return stats.asMap();
  }

  /// Evaluates given dice expression N times.
  Stream<int> rollN(String diceStr, int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll(diceStr);
    }
  }
}

/// uses welford's algorithm to compute variance for stddev along
/// with and other stats
///
/// long n = 0;
// double mu = 0.0;
// double sq = 0.0;
//
// void update(double x) {
//     ++n;
//     double muNew = mu + (x - mu)/n;
//     sq += (x - mu) * (x - muNew)
//     mu = muNew;
// }
// double mean() { return mu; }
// double var() { return n > 1 ? sq/n : 0.0; }
class Statsimator {
  num _minVal;
  num _maxVal;
  int _count = 0;
  bool _initialized = false;
  num _mean = 0.0;
  num _sq = 0.0;

  final _histogram = SplayTreeMap<num, int>();

  /// update current stats w/ new value
  void update(num val) {
    _count++;
    if (!_initialized) {
      _minVal = _maxVal = val;
      _initialized = true;
    } else {
      _minVal = min(_minVal, val);
      _maxVal = max(_maxVal, val);
    }

    _histogram[val] = (_histogram[val] ?? 0) + 1;

    var meanNew = _mean + (val - _mean) / _count;
    _sq += (val - _mean) * (val - meanNew);
    _mean = meanNew;
  }

  num get _variance => _count > 1 ? _sq / _count : 0.0;
  num get _stddev => sqrt(_variance);

  /// retrieve stats as map
  Map<String, dynamic> asMap({int precision = 3}) {
    return {
      'min': _minVal.toStringAsPrecision(precision),
      'max': _maxVal.toStringAsPrecision(precision),
      'count': _count,
      'histogram': _histogram,
      'mean': _mean.toStringAsPrecision(precision),
      'stddev': _stddev.toStringAsPrecision(precision),
    };
  }

  String get tmp => "thing";
}
