import 'dart:math';

import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/parser.dart';
import 'package:dart_dice_parser/src/results.dart';
import 'package:dart_dice_parser/src/stats.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:petitparser/petitparser.dart';

/// An abstract expression that can be evaluated.
abstract class DiceExpression {
  static final _log = Logger('DiceExpression');

  /// Parse the given input into a DiceExpression
  ///
  /// Throws [FormatException] if invalid
  static DiceExpression create(
    String input, [
    Random? random,
  ]) {
    final builder = parserBuilder(DiceRoller(random));
    final result = builder.parse(input);
    if (result is Failure) {
      throw FormatException(
        "Error parsing dice expression",
        input,
        result.position,
      );
    }
    return result.value;
  }

  /// each DiceExpression operation is callable (when we call the parsed string, this is the method that'll be used)
  RollResult call();

  /// Rolls the dice expression
  ///
  /// Throws [FormatException]
  @nonVirtual
  RollResult roll() {
    final result = this();
    _log.fine(() => "$result");
    return result;
  }

  /// Lazy iterable of rolling [num] times. Results returned as stream.
  ///
  /// Throws [FormatException]
  @nonVirtual
  Stream<RollResult> rollN(int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll();
    }
  }

  /// Performs [num] rolls and outputs stats (stddev, mean, min/max, and a histogram)
  ///
  /// Throws [FormatException]
  @nonVirtual
  Future<Map<String, dynamic>> stats({
    int num = 500,
  }) async {
    final stats = StatsCollector();

    await for (final r in rollN(num)) {
      stats.update(r.total);
    }
    return stats.asMap();
  }
}
