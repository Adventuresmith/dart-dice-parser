import 'package:logging/logging.dart';
import 'package:petitparser/petitparser.dart';

import 'dice_roller.dart';
import 'enums.dart';
import 'parser.dart';
import 'roll_result.dart';
import 'roll_summary.dart';
import 'stats.dart';

/// An abstract expression that can be evaluated.
abstract class DiceExpression {
  static final exprLogger = Logger('DiceExpression');
  static List<Function(RollResult)> listeners = [defaultListener];
  static List<Function(RollSummary)> summaryListeners = [];

  static void registerListener(Function(RollResult rollResult) callback) {
    listeners.add(callback);
  }

  static void registerSummaryListener(
    Function(RollSummary rollSummary) callback,
  ) {
    summaryListeners.add(callback);
  }

  static void clearListeners() {
    listeners.clear();
  }

  static void clearSummaryListeners() {
    listeners.clear();
  }

  static void callListeners(
    RollResult? rr, {
    Function(RollResult rr) onRoll = noopListener,
  }) {
    if (rr == null || rr.opType == OpType.value) return;
    callListeners(rr.left, onRoll: onRoll);
    callListeners(rr.right, onRoll: onRoll);
    for (final cb in listeners) {
      cb(rr);
    }
    onRoll(rr);
  }

  static void noopListener(RollResult rollResult) {}

  static void noopSummaryListener(RollSummary rollResult) {}

  static void defaultListener(RollResult rollResult) {
    exprLogger.fine(() => '$rollResult');
  }

  /// Parse the given input into a DiceExpression
  ///
  /// Throws [FormatException] if invalid
  static DiceExpression create(String input, {DiceRoller? roller}) {
    final builder = parserBuilder(DiceResultRoller(roller));
    final result = builder.parse(input);
    if (result is Failure) {
      throw FormatException(
        'Error parsing dice expression',
        input,
        result.position,
      );
    }
    return result.value;
  }

  /// each DiceExpression operation is callable (when we call the parsed string, this is the method that'll be used)
  Future<RollResult> call();

  /// Rolls the dice expression
  ///
  /// Throws [FormatException]
  Future<RollSummary> roll({
    Function(RollResult rollResult) onRoll = noopListener,
    Function(RollSummary rollSummary) onSummary = noopSummaryListener,
  }) async {
    final rollResult = await this();

    callListeners(rollResult, onRoll: onRoll);

    final summary = RollSummary(detailedResults: rollResult);
    for (final cb in summaryListeners) {
      cb(summary);
    }
    onSummary(summary);
    return summary;
  }

  /// Lazy iterable of rolling [num] times. Results returned as stream.
  ///
  /// Throws [FormatException]
  Stream<RollSummary> rollN(int num) async* {
    for (var i = 0; i < num; i++) {
      yield await roll();
    }
  }

  /// Performs [num] rolls and outputs stats (stddev, mean, min/max, and a histogram)
  ///
  /// Throws [FormatException]
  Future<Map<String, dynamic>> stats({int num = 1000}) async {
    final stats = StatsCollector();

    await for (final r in rollN(num)) {
      stats.update(r.total);
    }
    return stats.toJson();
  }
}
