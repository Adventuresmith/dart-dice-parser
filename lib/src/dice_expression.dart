import 'dart:math';

import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/parser.dart';
import 'package:dart_dice_parser/src/results.dart';
import 'package:dart_dice_parser/src/stats.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// An abstract expression that can be evaluated.
abstract class DiceExpression {
  // TODO: have an LRU cache of DiceExpressions? Or, treat that as out-of-scope for this library?
  // TODO: does it make sense to expose more of the AST? Or, have other ways of interrogating a roll result?

  static final _log = Logger('DiceExpression');
  static final _defaultParserBuilder =
      parserBuilder(DiceRoller(Random.secure()));

  /// Parse the given input into a DiceExpression
  ///
  /// Throws [FormatException] if invalid
  static DiceExpression create(String input, [Random? random]) {
    final builder = random == null
        ? _defaultParserBuilder
        : parserBuilder(DiceRoller(random));
    final result = builder.parse(input);
    if (result.isFailure) {
      throw FormatException(
        "Error parsing dice expression",
        input,
        result.position,
      );
    }
    return result.value;
  }

  /// each operation is callable (when we call the parsed string, this is the method that'll be used)
  RollResult call();

  /// Rolls the dice expression
  ///
  /// Throws [ArgumentError], [FormatException]
  @nonVirtual
  int roll() {
    final result = this();
    _log.fine(() => "$this => $result => ${result.value}");
    return result.value;
  }

  /// Lazy iterable of rolling [num] times. Results returned as stream.
  ///
  /// Throws [ArgumentError], [FormatException]
  @nonVirtual
  Stream<int> rollN(int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll();
    }
  }

  /// Performs [num] rolls and outputs stats (stddev, mean, min/max, and a histogram)
  ///
  /// Throws [ArgumentError], [FormatException]
  @nonVirtual
  Future<Map<String, dynamic>> stats({
    int num = 500,
  }) async {
    final stats = StatsCollector();

    await for (final r in rollN(num)) {
      stats.update(r);
    }
    return stats.asMap();
  }
}
