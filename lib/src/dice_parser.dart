import "dart:collection";
import "dart:math";

import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';

/// sum an Iterable of integers
int sum(Iterable<int> l) => l.reduce((a, b) => a + b);

/// A Parser for dice notation
///
class DiceParser {
  final Logger _log = Logger('DiceParser');

  final DiceRoller _roller;

  late Parser _evaluator;

  /// Constructs a dice parser, dice roller injectable for mocking random
  DiceParser([Random? random])
      : _roller = DiceRoller(random ?? Random.secure()) {
    _evaluator = _build();
  }

  Parser _build() {
    final builder = ExpressionBuilder();
    final root = failure().settable();
    // build groups in descending order of operations
    // * parens, ints
    // * variations of dice-expr
    // * multiply
    // * add/sub
    builder.group()
      // handle parens
      ..wrapper(char('(').trim(), char(')').trim(), (l, value, r) => value)
      // match ints. will return null if empty
      ..primitive(
        digit()
            .star()
            .flatten('integer expected') // create string result of digit*
            .trim() // trim whitespace
            .map((a) => a.isNotEmpty ? int.parse(a) : null),
      ); // TODO: return 0 instead of null?
    // exploding dice need to be higher precendence (before 'd')
    builder.group().left(string('d!!').trim(), _handleStdDice);
    builder.group().left(string('d!').trim(), _handleStdDice);
    builder.group()
      // fudge dice `AdF`
      ..postfix(string('dF').trim(), _handleSpecialDice)
      // percentile dice `Ad%`
      ..postfix(string('d%').trim(), _handleSpecialDice)
      // D66 dice, `AD66` aka A(1d6*10+1d6)
      ..postfix(string('D66').trim(), _handleSpecialDice)
      // `AdX`
      ..left(char('d').trim(), _handleStdDice);
    // before arithmetic, but after dice grouping... handle dice re-rolls, mods, drops
    builder.group()
      // cap/clamp  C> or C<
      ..left(string('C>').trim(), _handleRollResultModifiers)
      ..left(string('C<').trim(), _handleRollResultModifiers)
      ..left(string('c>').trim(), _handleRollResultModifiers)
      ..left(string('c<').trim(), _handleRollResultModifiers)
      // drop
      ..left(string('-<').trim(), _handleRollResultModifiers)
      ..left(string('->').trim(), _handleRollResultModifiers)
      ..left(string('-=').trim(), _handleRollResultModifiers)
      ..left(string('-L').trim(), _handleRollResultModifiers)
      ..left(string('-H').trim(), _handleRollResultModifiers)
      ..left(string('-l').trim(), _handleRollResultModifiers)
      ..left(string('-h').trim(), _handleRollResultModifiers);
    builder.group()
      // count
      ..left(string('#>').trim(), _handleRollResultOperation)
      ..left(string('#<').trim(), _handleRollResultOperation)
      ..left(string('#=').trim(), _handleRollResultOperation);
    builder
        .group()
        // count total -- needs to be lower precedence than the other counters
        .postfix(
          string('#').trim(),
          (a, op) => _handleRollResultOperation(a, '#', null),
        );
    // multiplication in different group than add/subtract to enforce order of operations
    builder.group().left(char('*').trim(), _handleArith);
    // addition is handled differently -- if operands are lists, the lists will be combined
    builder.group()
      ..left(char('+').trim(), _handleAdd)
      ..left(char('-').trim(), _handleArith);
    //return builder.build().end();

    root.set(builder.build());
    return root.end();
  }

  /// callback for operations which do something w/ the roll result (count =,>,<)
  int _handleRollResultOperation(a, String op, b) {
    int result;
    final resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
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
            "unknown roll modifier: $a$op${b ?? resolvedB}",
          );
      }
    } else {
      // log warning, this is a user-facing error
      _log.warning(
        () =>
            "prefix to roll operation $op must be a dice roll results, not $a",
      );
      result = 0;
    }
    _log.finer(() => "$a$op$resolvedB => $result");
    return result;
  }

  /// callback for operations that modify the roll (drop results, clamp, etc)
  List<int> _handleRollResultModifiers(a, String op, b) {
    List<int>? results;
    List<int>? dropped;
    final resolvedB = _resolveToInt(b, 1); // if b missing, assume '1'
    if (a is List<int>) {
      final localA = a.toList()..sort();
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
            "unknown roll modifier: $a$op${b ?? resolvedB}",
          );
      }
    } else if (a is int) {
      results = [a];
    } else {
      throw FormatException(
        "prefix to roll modifier $op must be a dice roll results, not $a",
      );
    }
    _log.finer(
      () =>
          "$a$op${b ?? resolvedB} => $results ${dropped != null ? '(dropped:$dropped)' : '[]'}",
    );
    return results;
  }

  /// callback for typical roll operations
  List<int> _handleStdDice(a, String op, x) {
    final resolvedA = _resolveToInt(a, 1);
    final resolvedX = _resolveToInt(x, 1);

    var results = <int>[];
    switch (op) {
      case 'd':
        results = _roller.roll(resolvedA, resolvedX);
        break;
      case "d!":
        results = _roller.rollWithExplode(
          ndice: resolvedA,
          nsides: resolvedX,
          explode: true,
        );
        break;
      case 'd!!':
        results = _roller.rollWithExplode(
          ndice: resolvedA,
          nsides: resolvedX,
          explode: true,
          explodeLimit: 1,
        );
        break;
    }

    _log.finer(() => "${a ?? resolvedA}$op${x ?? resolvedX} => $results");
    return results;
  }

  /// callback for roll of D66, d%, dF
  List<int> _handleSpecialDice(a, String op) {
    // if a null, assume 1; e.g. interpret 'd10' as '1d10'
    // if it's a list (i.e. a dice roll), sum the results
    final resolvedA = _resolveToInt(a, 1);
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
        throw FormatException("Unknown dice operator $a$op");
    }
    _log.finer(() => "${a ?? resolvedA}$op => $results");
    return results;
  }

  /// Return variable as in -- if null: return default, if List: sum
  int _resolveToInt(v, [int defaultVal = 0]) {
    if (v == null) {
      return defaultVal;
    } else if (v is Iterable<int>) {
      if (v.isEmpty) {
        return 0;
      } else {
        return sum(v);
      }
    } else if (v is int) {
      return v;
    } else {
      throw ArgumentError(
        "Invalid argument type for resolveInt: $v (${v.runtimeType})",
      );
    }
  }

  /// Handles addition. If both params are lists, return aggregate. Otherwise, return [sum]
  List<int> _handleAdd(a, String op, b) {
    final resolvedA = _resolveToInt(a);
    final resolvedB = _resolveToInt(b);
    var results = <int>[];
    if (a is List<int> && b is List<int>) {
      results.addAll(a);
      results.addAll(b);
    } else {
      // have to return sum wrapped in list, since return type of this method is List<int>
      results = [resolvedA + resolvedB];
    }
    _log.finer(() => "${a ?? resolvedA}$op${b ?? resolvedB} => $results");
    return results;
  }

  /// Handles arithmetic operations -- mult, sub
  int _handleArith(a, String op, b) {
    final resolvedA = _resolveToInt(a);
    final resolvedB = _resolveToInt(b);
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

  /// Parses the given dice expression return evaluate-able Result.
  Result<dynamic> evaluate(String diceStr) {
    return _evaluator.parse(diceStr);
  }

  /// Evaluates the input dice expression and returns evaluated result.
  ///
  /// throws FormatException if unable to parse expression
  /// throws RangeError if dice expression is invalid (e.g. a zero-sided die)
  int roll(String diceStr) {
    final result = evaluate(diceStr);
    if (result.isFailure) {
      throw FormatException(
        "Error parsing dice expression",
        diceStr,
        result.position,
      );
    }
    final res = _resolveToInt(result.value);
    _log.fine("$diceStr => $res");
    return res;
  }

  /// Performs N rolls and outputs stats (stddev, mean, min/max, and a histogram)
  Future<Map<String, dynamic>> stats({
    required String diceStr,
    int numRolls = 10000,
    int precision = 3,
  }) async {
    final stats = Statsimator();

    await for (final r in rollN(diceStr, numRolls)) {
      stats.update(r);
    }
    return stats.asMap();
  }

  /// Evaluates given dice expression N times. Results returned as stream.
  Stream<int> rollN(String diceStr, int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll(diceStr);
    }
  }
}

/// uses welford's algorithm to compute variance for stddev along
/// with other stats
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
  int _minVal = 0;
  int _maxVal = 0;
  int _count = 0;
  bool _initialized = false;
  double _mean = 0.0;
  double _sq = 0.0;

  final _histogram = SplayTreeMap<int, int>();

  /// update current stats w/ new value
  void update(int val) {
    _count++;
    if (!_initialized) {
      _minVal = _maxVal = val;
      _initialized = true;
    } else {
      _minVal = min(_minVal, val);
      _maxVal = max(_maxVal, val);
    }

    _histogram[val] = (_histogram[val] ?? 0) + 1;

    final meanNew = _mean + (val - _mean) / _count;
    _sq += (val - _mean) * (val - meanNew);
    _mean = meanNew;
  }

  num get _variance => _count > 1 ? _sq / _count : 0.0;
  num get _stddev => sqrt(_variance);

  /// retrieve stats as map
  UnmodifiableMapView<String, dynamic> asMap({int precision = 3}) {
    return UnmodifiableMapView({
      'mean': double.parse(_mean.toStringAsPrecision(precision)),
      'stddev': double.parse(_stddev.toStringAsPrecision(precision)),
      'min': _minVal,
      'max': _maxVal,
      'count': _count,
      'histogram': _histogram,
    });
  }
}
