import 'package:collection/collection.dart';
import 'package:dart_dice_parser/src/stats.dart';
import 'package:dart_dice_parser/src/utils.dart';

/// An abstract expression that can be evaluated.
abstract class DiceExpression with LoggingMixin {
  /// each operation is callable (when we call the parsed string, this is the method that'll be used)
  List<int> call();

  /// rolls the dice expression
  int roll() {
    final result = this();
    final sum = result.sum;
    log.fine(() => "$this => $result => $sum");
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
