import 'package:collection/collection.dart';

enum RollMetadata {
  /// all the dice rolled by the operation
  rolled,

  /// any dice dropped by the operation
  dropped,

  /// count of items
  count,

  /// success count
  successes,

  /// failure count
  failures,

  /// critical success count
  critSuccesses,

  /// critical failure count
  critFailures;

  @override
  String toString() => name;
}

/// The result of rolling a dice expression.
///
class RollResult {
  RollResult({
    required this.expression,
    this.ndice = 0,
    this.nsides = 0,
    this.results = const [],
    this.metadata = const {},
  }) {
    total = results.sum;
  }

  /// sum of [results]
  late int total = 0;

  /// the parsed expression
  final String expression;

  /// number of sides. may be zero if complex expression
  final int nsides;

  /// number of dice rolled. may be zero if complex expression
  final int ndice;

  /// the results of the operation
  final List<int> results;

  /// any metadata the operation may have recorded
  final Map<RollMetadata, Object> metadata;

  /// Get the total, or if results are empty return result of calling [defaultCb].
  int totalOrDefault(int Function() defaultCb) {
    if (results.isEmpty) {
      return defaultCb();
    }
    return total;
  }

  @override
  String toString() {
    return '$expression => RollResult(total: $total, results: $results $metadata)';
  }
}
