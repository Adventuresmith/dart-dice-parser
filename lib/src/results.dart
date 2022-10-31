import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

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
}

/// The result of rolling a dice expression.
///
/// A [RollResult] is modeled as a binary tree. The dice expression
/// is parsed into a [DiceExpression] and when evaluated the results
/// should (mostly) reflect the structure of AST.
///
/// In general, most users will just care about the root node of the tree.
/// But, depending on the information you want to from the evaluated dice rolls,
/// you may need to traverse the tree to find all the events.

class RollResult with EquatableMixin {
  RollResult({
    required this.expression,
    this.ndice = 0,
    this.nsides = 0,
    this.results = const [],
    this.metadata = const {},
    this.left,
    this.right,
  }) {
    total = results.sum;
  }

  /// factory constructor to merge [other] with the params of this function
  /// and produce a new [RollResult].
  factory RollResult.fromRollResult(
    RollResult other, {
    required String expression,
    int? ndice,
    int? nsides,
    List<int>? results,
    Map<String, Object> metadata = const {},
    RollResult? left,
    RollResult? right,
  }) {
    return RollResult(
      expression: expression,
      ndice: ndice ?? other.ndice,
      nsides: nsides ?? other.nsides,
      results: results ?? other.results,
      metadata: {...other.metadata, ...metadata},
      left: left ?? other.left,
      right: right ?? other.right,
    );
  }

  /// addition operator for [RollResult].
  ///
  /// in the returned results, nsides will be max(nsides, other.nsides).
  /// this is so we can explode a dice expr like `(2d6 + 1)!`.
  /// A side-effect of this decision is `(2d6 + 2d10)!` will explode with 10s, not 6s.
  RollResult operator +(RollResult other) {
    return RollResult(
      expression: "($expression+${other.expression})",
      results: results + other.results,
      nsides: max(nsides, other.nsides),
      left: this,
      right: other,
    );
  }

  /// multiplication operator for [RollResult].
  ///
  /// Results are collapsed into a single value (the result of multiplication).
  ///
  RollResult operator *(RollResult other) {
    return RollResult(
      expression: "($expression*${other.expression})",
      results: [totalOrDefault(() => 0) * other.totalOrDefault(() => 0)],
      left: this,
      right: other,
    );
  }

  /// subtraction operator for [RollResult].
  ///
  /// Results create new list lhs.results + (-1)*(other.results).
  ///
  RollResult operator -(RollResult other) {
    return RollResult(
      expression: "($expression-${other.expression})",
      results: results + other.results.map((v) => v * -1).toList(),
      nsides: max(nsides, other.nsides),
      left: this,
      right: other,
    );
  }

  /// sum of [results]
  late int total = 0;

  /// the parsed expression
  final String expression;

  /// number of sides. may be zero if complex expression or arithmetic result
  final int nsides;

  /// number of dice rolled. may be zero if complex expression or arithmetic result
  final int ndice;

  /// the results of the evaluating the expression
  final List<int> results;

  /// any metadata the operation may have recorded
  final Map<String, Object> metadata;

  final RollResult? left;
  final RollResult? right;

  @override
  List<Object?> get props =>
      [total, expression, nsides, ndice, results, metadata, left, right];

  /// Get the total, or if results are empty return result of calling [defaultCb].
  int totalOrDefault(int Function() defaultCb) {
    if (results.isEmpty) {
      return defaultCb();
    }
    return total;
  }

  @override
  String toString() {
    return '$expression => RollResult(total: $total, results: $results${metadata.isNotEmpty ? ", metadata: $metadata" : ""})';
  }

  Map<String, Object?> toJson() => {
        'expression': expression,
        'total': total,
        'nsides': nsides,
        'ndice': ndice,
        'results': results,
        'metadata': metadata,
        'left': left?.toJson(),
        'right': right?.toJson(),
      };
}
