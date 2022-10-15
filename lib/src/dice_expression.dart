import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/dice_roller.dart';
import 'package:dart_dice_parser/src/parser.dart';
import 'package:dart_dice_parser/src/stats.dart';
import 'package:dart_dice_parser/src/utils.dart';

final _defaultParserBuilder = parserBuilder(DiceRoller());

/// An abstract expression that can be evaluated.
abstract class DiceExpression with LoggingMixin {
  /// parse the given input into a DiceExpression
  /// throws format exception if invalid
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
  List<int> call();

  /// rolls the dice expression
  int roll() {
    final result = this();
    final sum = result.sum;
    logger.fine(() => "$this => $result => $sum");
    return sum;
  }

  /// Lazy iterable of rolling N times. Results returned as stream.
  Stream<int> rollN(int num) async* {
    for (var i = 0; i < num; i++) {
      yield roll();
    }
  }

  /// Performs N rolls and outputs stats (stddev, mean, min/max, and a histogram)
  Future<Map<String, dynamic>> stats({
    int num = 500,
    int precision = 3,
  }) async {
    final stats = StatsCollector();

    await for (final r in rollN(num)) {
      stats.update(r);
    }
    return stats.asMap();
  }
}
