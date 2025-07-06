import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'enums.dart';
import 'extensions.dart';
import 'rolled_die.dart';

/// [RollResult] represents the result of evaluating a particular node of the AST.
///
class RollResult extends Equatable {
  RollResult({
    required this.expression,
    required this.opType,
    Iterable<RolledDie> results = const IList.empty(),
    Iterable<RolledDie> discarded = const IList.empty(),
    this.left,
    this.right,
  }) : results = IList(results),
       discarded = IList(discarded);

  /// factory constructor to merge [other] with the params of this function
  /// and produce a new [RollResult].
  factory RollResult.fromRollResult(
    RollResult other, {
    required String expression,
    OpType? opType,
    Iterable<RolledDie>? results,
    Iterable<RolledDie>? discarded,
    RollResult? left,
    RollResult? right,
  }) => RollResult(
    expression: expression,
    opType: opType ?? other.opType,
    results: IList.orNull(results) ?? other.results,
    discarded: IList.orNull(discarded) ?? other.discarded,
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
    discarded: discarded + other.discarded,
    opType: OpType.add,
    left: this,
    right: other,
  );

  /// multiplication operator for [RollResult].
  ///
  /// Results are collapsed into a single value (the result of multiplication), all other rolled die are discarded.
  ///
  RollResult operator *(RollResult other) => RollResult.fromRollResult(
    other,
    expression: '($expression * ${other.expression})',
    results: [
      RolledDie.singleVal(
        result: results.sum * other.results.sum,
        from: results + other.results,
      ),
    ],
    discarded: [
      ...results.map(RolledDie.discard),
      ...other.results.map(RolledDie.discard),
    ],
    opType: OpType.multiply,
    left: this,
    right: other,
  );

  /// subtraction operator for [RollResult].
  ///
  /// Results create new list lhs.results + (-1)*(other.results).
  /// other.results are discarded, and a single value result is added
  ///
  RollResult operator -(RollResult other) => RollResult.fromRollResult(
    other,
    expression: '($expression - ${other.expression})',
    opType: OpType.subtract,
    results: [
      ...results,
      RolledDie.singleVal(result: -1 * other.results.sum, from: other.results),
    ],
    discarded: [...other.results.map(RolledDie.discard)],
    left: this,
    right: other,
  );

  /// the parsed expression
  final String expression;

  /// the results of the evaluating the expression
  final IList<RolledDie> results;
  final IList<RolledDie> discarded;

  final RollResult? left;
  final RollResult? right;

  final OpType opType;

  /// sum of [results]
  int get total => totalOrDefault(() => 0);

  int get successCount => results.successCount;

  int get failureCount => results.failureCount;

  int get critSuccessCount => results.critSuccessCount;

  int get critFailureCount => results.critFailureCount;

  @override
  List<Object?> get props => [
    expression,
    opType,
    results,
    discarded,
    opType,
    //left,
    //right,
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
    final buffer = StringBuffer();
    buffer.write(
      '$expression =${opType.name}=> RollResult(${opType == OpType.value ? 'value' : 'total'}: $total',
    );
    if (opType != OpType.value) {
      if (results.isNotEmpty) {
        buffer.write(', results: ${results.toString(false)}');
      }
      if (discarded.isNotEmpty) {
        buffer.write(', discarded: ${discarded.toString(false)}');
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String toStringPretty({String indent = ''}) => pprint(this, indent: indent);

  Map<String, dynamic> toJson() =>
      {
        'expression': expression,
        'opType': opType.name,
        'results': results.map((e) => e.toJson()).toList(growable: false),
        'discarded': discarded.map((e) => e.toJson()).toList(growable: false),
        'left': left != null && left?.opType != OpType.value
            ? left?.toJson()
            : null,
        'right': right != null && right?.opType != OpType.value
            ? right?.toJson()
            : null,
        'total': total,
        'successCount': successCount,
        'failureCount': failureCount,
        'critSuccessCount': critSuccessCount,
        'critFailureCount': critFailureCount,
      }..removeWhere(
        (k, v) =>
            v == null ||
            (v is Map && v.isEmpty) ||
            (v is Iterable && v.isEmpty) ||
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
      ..write(pprint(rr.right, indent: '$indent    '));
  }

  return buffer.toString();
}
