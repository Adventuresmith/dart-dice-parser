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
/// RollResult is a binary tree with [left] and [right] branches
/// representing the parsed dice expression.
class RollResult {
  RollResult({
    required this.expression,
    required this.operation,
    this.ndice = 0,
    this.nsides = 0,
    this.results = const [],
    this.metadata = const {},
    this.left,
    this.right,
  }) {
    total = results.sum;
  }

  /// sum of [results]
  int total = 0;

  /// the parsed expression
  final String expression;

  /// the operation token
  final String operation;

  /// number of sides. may be zero if complex expression
  final int nsides;

  /// number of dice rolled. may be zero if complex expression
  final int ndice;

  /// the results of the operation -- will be a subset of [rolled]
  final List<int> results;

  /// any metadata the operation may have recorded
  final Map<RollMetadata, Object> metadata;

  /// left RollResult of expression
  final RollResult? left;

  /// right RollResult of expression
  final RollResult? right;

  static int _defaultCb() => throw ArgumentError("missing value");

  /// Evaluate this roll result (typically, sum the rolls).
  /// However, if result is a Value and empty, return result of calling [defaultCb].
  /// if [defaultCb] not provided, 0 will be returned.
  int resolveToInt([int Function() defaultCb = _defaultCb]) {
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
