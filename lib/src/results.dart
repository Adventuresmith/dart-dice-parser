import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

enum OpType {
  value, // leaf nodes which are simple integer values
  add,
  subtract,
  multiply,
  count,
  drop,
  clamp,
  rollDice,
  rollFudge,
  rollPercent,
  rollD66,
  reroll,
  compound,
  explode,
}

enum CountType {
  count,
  success,
  failure,
  critSuccess,
  critFailure;
}

/// RollScore represents the # of successes and failures.
class RollScore extends Equatable {
  const RollScore({
    this.successes = const [],
    this.failures = const [],
    this.critSuccesses = const [],
    this.critFailures = const [],
  });

  factory RollScore.forCountType(CountType countType, List<int> vals) {
    switch (countType) {
      case CountType.success:
        return RollScore(
          successes: vals,
        );
      case CountType.failure:
        return RollScore(
          failures: vals,
        );
      case CountType.critSuccess:
        return RollScore(
          critSuccesses: vals,
        );
      case CountType.critFailure:
        return RollScore(
          critFailures: vals,
        );
      case CountType.count:
        throw UnimplementedError();
    }
  }

  final List<int> successes;
  final List<int> failures;
  final List<int> critSuccesses;
  final List<int> critFailures;

  int get successCount => successes.length;

  int get failureCount => failures.length;

  int get critSuccessesCount => critSuccesses.length;

  int get critFailureCount => critFailures.length;

  bool get isEmpty =>
      successes.isEmpty &&
      failures.isEmpty &&
      critSuccesses.isEmpty &&
      critFailures.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool get hasSuccesses => successes.isNotEmpty;

  bool get hasFailures => failures.isNotEmpty;

  bool get hasCritSuccesses => critSuccesses.isNotEmpty;

  bool get hasCritFailures => critFailures.isNotEmpty;

  @override
  List<Object?> get props => [
        successes,
        failures,
        critSuccesses,
        critFailures,
      ];

  @override
  String toString() => '${toJson()}';

  Map<String, dynamic> toJson() => {
        'successes': successes,
        'failures': failures,
        'critSuccesses': critSuccesses,
        'critFailures': critFailures,
      }..removeWhere((k, v) => (v is List && v.isEmpty));

  RollScore operator +(RollScore other) => RollScore(
        successes: successes + other.successes,
        failures: failures + other.failures,
        critSuccesses: critSuccesses + other.critSuccesses,
        critFailures: critFailures + other.critFailures,
      );
}

/// RollMetadata represents 'interesting' things that happens during certain operations.
/// This will include the 'score' (if any), a list of which dice were rolled
/// by the operation, and a list of which dice were discarded by the operation.
///
class RollMetadata extends Equatable {
  const RollMetadata({
    this.rolled = const [],
    this.discarded = const [],
    this.score = const RollScore(),
  });

  final List<int> rolled;
  final List<int> discarded;
  final RollScore score;

  bool get isEmpty => rolled.isEmpty && discarded.isEmpty && score.isEmpty;

  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [
        rolled,
        discarded,
        score,
      ];

  @override
  String toString() => '${toJson()}';

  Map<String, dynamic> toJson() => {
        'rolled': rolled,
        'discarded': discarded,
        'score': score.toJson(),
      }..removeWhere(
          (k, v) => (v is List && v.isEmpty) || (v is Map && v.isEmpty),
        );

  RollMetadata operator +(RollMetadata other) => RollMetadata(
        rolled: rolled + other.rolled,
        discarded: discarded + other.discarded,
        score: score + other.score,
      );
}

/// [RollSummary] is the final result of rolling a dice expression.
/// It rolls up the metadata of sub-expressions, and includes a `detailResults`
/// if the caller wants to do something interesting to display the result graph.
///
/// A [RollResult] is modeled as a binary tree. The dice expression
/// is parsed into an AST, and when rolled the results reflect the structure of
/// the AST.
///
/// In general, users will only care about the root node of the tree.
/// But, depending on the information you want from the evaluated dice rolls,
/// you may need to traverse the tree to inspect all the events.

class RollSummary extends Equatable {
  RollSummary({
    required this.detailedResults,
  }) {
    total = detailedResults.results.sum;
    results = detailedResults.results;
    expression = detailedResults.expression;
    metadata = rollupMetadata(detailedResults);
  }

  final RollResult detailedResults;

  /// sum of [results]
  late final int total;

  /// the parsed expression
  late final String expression;

  /// the results of the evaluating the expression
  late final List<int> results;
  late final RollMetadata metadata;

  bool get hasSuccesses => metadata.score.hasSuccesses;

  bool get hasFailures => metadata.score.hasFailures;

  bool get hasCritSuccesses => metadata.score.hasCritSuccesses;

  bool get hasCritFailures => metadata.score.hasCritFailures;

  @override
  List<Object?> get props => [
        total,
        expression,
        results,
        detailedResults,
        metadata,
      ];

  @override
  String toString() {
    final buffer = StringBuffer(
      '$expression ===> RollSummary(total: $total, results: $results',
    );
    if (metadata.isNotEmpty) {
      buffer.write(', metadata: $metadata');
    }
    buffer.write(')');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'total': total,
        'results': results,
        'detailedResults': detailedResults.toJson(),
        'metadata': metadata.toJson(),
      }..removeWhere(
          (k, v) =>
              v == null ||
              (v is Map && v.isEmpty) ||
              (v is List && v.isEmpty) ||
              (v is RollScore && v.isEmpty) ||
              (v is int && v == 0),
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

/// [RollResult] represents the result of evaluating a particular node of the AST.
///
class RollResult extends Equatable {
  const RollResult({
    required this.expression,
    required this.opType,
    this.ndice = 0,
    this.nsides = 0,
    this.results = const [],
    this.metadata = const RollMetadata(),
    this.left,
    this.right,
  });

  /// factory constructor to merge [other] with the params of this function
  /// and produce a new [RollResult].
  factory RollResult.fromRollResult(
    RollResult other, {
    required String expression,
    OpType? opType,
    int? ndice,
    int? nsides,
    List<int>? results,
    RollMetadata metadata = const RollMetadata(),
    RollResult? left,
    RollResult? right,
  }) =>
      RollResult(
        expression: expression,
        ndice: ndice ?? other.ndice,
        nsides: nsides ?? other.nsides,
        results: results ?? other.results,
        opType: opType ?? other.opType,
        metadata: metadata,
        left: left ?? other.left,
        right: right ?? other.right,
      );

  /// addition operator for [RollResult].
  ///
  /// in the returned results, nsides will be max(nsides, other.nsides).
  /// this is so we can explode a dice expr like `(2d6 + 1)!`.
  /// NOTE: A side-effect of this decision is `(2d6 + 2d10)!` will explode with 10s, not 6s.
  RollResult operator +(RollResult other) => RollResult.fromRollResult(
        other,
        expression: '($expression + ${other.expression})',
        results: results + other.results,
        nsides: max(nsides, other.nsides),
        opType: OpType.add,
        left: this,
        right: other,
      );

  /// multiplication operator for [RollResult].
  ///
  /// Results are collapsed into a single value (the result of multiplication).
  ///
  RollResult operator *(RollResult other) => RollResult.fromRollResult(
        other,
        expression: '($expression * ${other.expression})',
        results: [results.sum * other.results.sum],
        opType: OpType.multiply,
        left: this,
        right: other,
      );

  /// subtraction operator for [RollResult].
  ///
  /// Results create new list lhs.results + (-1)*(other.results).
  ///
  RollResult operator -(RollResult other) => RollResult.fromRollResult(
        other,
        expression: '($expression - ${other.expression})',
        opType: OpType.subtract,
        results: results + other.results.map((v) => v * -1).toList(),
        nsides: max(nsides, other.nsides),
        left: this,
        right: other,
      );

  /// the parsed expression
  final String expression;

  /// number of sides. may be zero if complex expression or arithmetic result
  final int nsides;

  /// number of dice rolled. may be zero if complex expression or arithmetic result
  final int ndice;

  /// the results of the evaluating the expression
  final List<int> results;

  final RollMetadata metadata;

  final RollResult? left;
  final RollResult? right;

  final OpType opType;

  @override
  List<Object?> get props => [
        expression,
        opType,
        nsides,
        ndice,
        results,
        metadata,
        left,
        right,
        opType,
      ];

  /// Get the total, or if results are empty return result of calling [defaultCb].
  int totalOrDefault(int Function() defaultCb) {
    if (results.isEmpty) {
      return defaultCb();
    }
    return results.sum;
  }

  @override
  String toString() {
    if (opType == OpType.value) {
      return '$expression => RollResult(value: ${results.sum})';
    } else {
      final buffer = StringBuffer();
      buffer.write(
        '$expression =${opType.name}=> RollResult(total: ${results.sum}, results: $results',
      );
      if (metadata.isNotEmpty) {
        buffer.write(', metadata: $metadata');
      }
      buffer.write(')');
      return buffer.toString();
    }
  }

  String toStringPretty({String indent = ''}) => pprint(this, indent: indent);

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'opType': opType.name,
        'nsides': nsides,
        'ndice': ndice,
        'results': results,
        'metadata': metadata.toJson(),
        'left': left != null && left?.opType != OpType.value
            ? left?.toJson()
            : null,
        'right': right != null && right?.opType != OpType.value
            ? right?.toJson()
            : null,
      }..removeWhere(
          (k, v) =>
              v == null ||
              (v is Map && v.isEmpty) ||
              (v is List && v.isEmpty) ||
              (v is int && v == 0),
        );
}

String pprint(RollResult? rr, {String indent = ''}) {
  if (rr == null) {
    return '';
  }
  final buffer = StringBuffer(indent);
  buffer.write(rr.toString());
  if (rr.left != null && rr.left?.opType != OpType.value) {
    buffer
      ..write('\n')
      ..write(pprint(rr.left, indent: '$indent    '));
  }
  if (rr.right != null && rr.right?.opType != OpType.value) {
    buffer
      ..write('\n')
      ..write(
        pprint(
          rr.right,
          indent: '$indent    ',
        ),
      );
  }

  return buffer.toString();
}

RollMetadata rollupMetadata(RollResult? rr) {
  if (rr == null || rr.opType == OpType.value) {
    return const RollMetadata();
  }

  return rollupMetadata(rr.left) + rollupMetadata(rr.right) + rr.metadata;
}
