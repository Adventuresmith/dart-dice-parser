import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'extensions.dart';
import 'roll_result.dart';
import 'rolled_die.dart';

/// [RollSummary] is the final result of rolling a dice expression.
/// It rolls up the metadata of sub-expressions, and includes a `detailResults`
/// if the caller wants to do something interesting to display the result graph.
///
/// A [RollResult] is modeled as a binary tree. The dice expression
/// is parsed into an AST, and when rolled the results reflect the structure of
/// that AST.
///
/// In general, users will only care about the root node of the tree.
/// But, depending on the information you want from the evaluated dice rolls,
/// you may need to traverse the tree to inspect all the events.

class RollSummary extends Equatable {
  RollSummary({required this.detailedResults})
    : total = detailedResults.results.sum,
      results = IList(detailedResults.results),
      discarded = IList(detailedResults.discarded),
      expression = detailedResults.expression,
      successCount = detailedResults.results.successCount,
      failureCount = detailedResults.results.failureCount,
      critSuccessCount = detailedResults.results.critSuccessCount,
      critFailureCount = detailedResults.results.critFailureCount;

  final RollResult detailedResults;

  /// sum of [results]
  late final int total;
  late final int successCount;
  late final int failureCount;
  late final int critSuccessCount;
  late final int critFailureCount;

  /// the parsed expression
  late final String expression;

  /// the results of the evaluating the expression
  late final IList<RolledDie> results;

  /// the dice we lost along the way
  late final IList<RolledDie> discarded;

  @override
  List<Object?> get props => [
    total,
    successCount,
    failureCount,
    critSuccessCount,
    critFailureCount,
    expression,
    results,
    discarded,
  ];

  @override
  String toString() {
    final buffer = StringBuffer(
      '$expression ===> RollSummary(total: $total, results: ${results.toString(false)}',
    );
    if (discarded.isNotEmpty) {
      buffer.write(', discarded: ${discarded.toString(false)}');
    }
    final params = {
      'successCount': successCount,
      'failureCount': failureCount,
      'critSuccessCount': critSuccessCount,
      'critFailureCount': critFailureCount,
    }..removeWhere((k, v) => v == 0);

    if (params.isNotEmpty) {
      buffer.write(', ');
      buffer.writeAll(
        params.entries.map((entry) => '${entry.key}: ${entry.value}'),
        ', ',
      );
    }

    buffer.write(')');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() =>
      {
        'expression': expression,
        'total': total,
        'successCount': successCount,
        'failureCount': failureCount,
        'critSuccessCount': critSuccessCount,
        'critFailureCount': critFailureCount,
        'results': results.map((e) => e.toJson()).toList(growable: false),
        'discarded': discarded.map((e) => e.toJson()).toList(growable: false),
        'detailedResults': detailedResults.toJson(),
      }..removeWhere(
        (k, v) =>
            v == null ||
            (v is Map && v.isEmpty) ||
            (v is Iterable && v.isEmpty) ||
            (v is int && v == 0) ||
            (v is bool && !v),
      );

  String toStringPretty() {
    final buffer = StringBuffer();
    buffer
      ..write(toString())
      ..write('\n')
      ..write(detailedResults.toStringPretty(indent: '  '));

    return buffer.toString();
  }
}
