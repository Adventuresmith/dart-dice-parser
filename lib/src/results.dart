import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

/// types of die
enum DieType {
  polyhedral, // normal polyhedral (1d6, 1d20, etc)
  fudge, // fudge dice
  d66, // 1D66 (equivalent to `1d6*10 + 1d6`).
  special, // 1d[1,3,5,7,9]
  singleVal, // single value (e.g. a sum or count of dice)
}

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
  rollVals,
  reroll,
  compound,
  explode,
}

enum CountType { count, success, failure, critSuccess, critFailure }

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
  RollSummary({required this.detailedResults}) {
    total = detailedResults.results.sum;
    results = detailedResults.results;
    discarded = detailedResults.discarded;
    expression = detailedResults.expression;
    successCount = detailedResults.results.successCount;
    failureCount = detailedResults.results.failureCount;
    critSuccessCount = detailedResults.results.critSuccessCount;
    critFailureCount = detailedResults.results.critFailureCount;
  }

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
  late final List<RolledDie> results;

  /// the dice we lost along the way
  late final List<RolledDie> discarded;

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
      '$expression ===> RollSummary(total: $total, results: $results',
    );
    if (discarded.isNotEmpty) {
      buffer.write(', discarded: $discarded');
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
            (v is List && v.isEmpty) ||
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

/// representation of a single dice roll result.
class RolledDie extends Equatable implements Comparable<RolledDie> {
  static const defaultFudgeVals = [-1, -1, 0, 0, 1, 1];

  const RolledDie({
    required this.result,
    required this.dieType,
    this.nsides = 0,
    this.potentialValues = const [],
    this.discarded = false,
    this.success = false,
    this.failure = false,
    this.critSuccess = false,
    this.critFailure = false,
    this.exploded = false,
    this.explosion = false,
    this.compoundedFinal = false,
    this.compounded = false,
    this.rerolled = false,
    this.clampCeiling = false,
    this.clampFloor = false,
    this.modifiedFrom,
  });

  factory RolledDie.polyhedral({required int result, required int nsides}) =>
      RolledDie(result: result, nsides: nsides, dieType: DieType.polyhedral);

  factory RolledDie.fudge({required int result}) => RolledDie(
    result: result,
    nsides: defaultFudgeVals.length,
    dieType: DieType.fudge,
    potentialValues: defaultFudgeVals,
  );

  factory RolledDie.singleVal({required int result}) =>
      RolledDie(result: result, dieType: DieType.singleVal);

  factory RolledDie.d66({required int result}) =>
      RolledDie(result: result, dieType: DieType.d66);

  factory RolledDie.copyWith(
    RolledDie other, {
    int? result,
    bool? discarded,
    bool? success,
    bool? failure,
    bool? critSuccess,
    bool? critFailure,
    bool? exploded,
    bool? explosion,
    bool? compounded,
    bool? compoundedFinal,
    bool? rerolled,
    bool? clampHigh,
    bool? clampLow,
  }) => RolledDie(
    potentialValues: other.potentialValues,
    nsides: other.nsides,
    dieType: other.dieType,
    result: result ?? other.result,
    discarded: discarded ?? other.discarded,
    success: success ?? other.success,
    failure: failure ?? other.failure,
    critSuccess: critSuccess ?? other.critSuccess,
    critFailure: critFailure ?? other.critFailure,
    exploded: exploded ?? other.exploded,
    explosion: explosion ?? other.explosion,
    compounded: compounded ?? other.compounded,
    compoundedFinal: compoundedFinal ?? other.compoundedFinal,
    rerolled: rerolled ?? other.rerolled,
    clampCeiling: clampHigh ?? other.clampCeiling,
    clampFloor: clampLow ?? other.clampFloor,
    modifiedFrom: other,
  );

  factory RolledDie.discard(RolledDie other) =>
      RolledDie.copyWith(other, discarded: true);

  factory RolledDie.scoreForCountType(
    RolledDie other, {
    required CountType countType,
  }) => RolledDie.copyWith(
    other,
    success: other.success || countType == CountType.success,
    failure: other.failure || countType == CountType.failure,
    critSuccess: other.critSuccess || countType == CountType.critSuccess,
    critFailure: other.critFailure || countType == CountType.critFailure,
  );

  /// the rolled result
  final int result;

  /// the number of sides on the die. Generally only set if dieType == polyhedral
  final int nsides;

  /// the die faces (potential values).
  /// this will be empty for polyhedral roles -- values will be range of (0,nsides]
  final List<int> potentialValues;

  /// true if the result has been discarded
  final bool discarded;

  bool get isDiscarded => discarded;

  // TODO: is this true? can fudge dice explode?
  bool get isExplodable => dieType == DieType.polyhedral;

  bool get isCompoundable => isExplodable;

  /// whether the die was scored as a 'success'
  final bool success;

  /// whether the die was scored as a 'failure'
  final bool failure;

  /// whether the die was scored as a 'critical success'
  final bool critSuccess;

  /// whether the die was scored as a 'critical failure'
  final bool critFailure;

  /// the type of die
  final DieType dieType;

  final RolledDie? modifiedFrom;

  /// true if the die exploded
  final bool exploded;

  /// true if the die is the result of a die exploding
  final bool explosion;

  /// true if the die was discarded as a roll during compounding
  final bool compounded;

  /// true if the die is the sum a multiple die due to compounding
  final bool compoundedFinal;
  final bool rerolled;
  final bool clampCeiling;
  final bool clampFloor;

  @override
  List<Object?> get props => [
    result,
    nsides,
    potentialValues,
    dieType,
    discarded,
    success,
    failure,
    critFailure,
    critSuccess,
    exploded,
    explosion,
    compounded,
    compoundedFinal,
    rerolled,
    clampCeiling,
    clampFloor,
  ];

  Map<String, dynamic> toJson() =>
      {
        'result': result,
        'nsides': nsides,
        'vals': potentialValues,
        'dieType': dieType.name,
        'discarded': discarded,
        'success': success,
        'failure': failure,
        'critSuccess': critSuccess,
        'critFailure': critFailure,
        'exploded': exploded,
        'explosion': explosion,
        'compounded': compounded,
        'compoundedFinal': compoundedFinal,
        'rerolled': rerolled,
        'clampHigh': clampCeiling,
        'clampLow': clampFloor,
      }..removeWhere(
        (k, v) =>
            v == null ||
            (v is Map && v.isEmpty) ||
            (v is List && v.isEmpty) ||
            (v is int && v == 0) ||
            (v is bool && !v),
      );

  String getDieGlyph() {
    switch (dieType) {
      case DieType.polyhedral:
        return 'd$nsides';
      case DieType.fudge:
        return 'dF';
      case DieType.d66:
        return 'D66';
      case DieType.singleVal:
        return '';
      default:
        return '?';
    }
  }

  String getDieStateGlyphs() {
    final buffer = StringBuffer();

    if (discarded) {
      buffer.write('⛔︎');
    }
    if (rerolled) {
      buffer.write('↩');
    }
    if (exploded) {
      buffer.write('💣'); //'⇪');
    }
    if (explosion) {
      buffer.write('🔥'); //'⇪');
    }
    if (compoundedFinal) {
      buffer.write('∑');
    }
    if (compounded) {
      buffer.write('+');
    }
    if (clampCeiling) {
      buffer.write('⌉');
    }
    if (clampFloor) {
      buffer.write('⌋');
    }
    if (success) {
      buffer.write('✓');
    }
    if (failure) {
      buffer.write('✗');
    }
    if (critSuccess) {
      buffer.write('✅');
    }
    if (critFailure) {
      buffer.write('❌'); //'☠'
    }
    return buffer.toString();
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(result);
    buffer.write('(');
    buffer.write(getDieGlyph());
    buffer.write(getDieStateGlyphs());
    buffer.write(')');
    return buffer.toString();
  }

  @override
  int compareTo(RolledDie other) => result - other.result;
}

extension RolledDieListExtensions on List<RolledDie> {
  int get sum => map((d) => d.result).fold(0, (sum, i) => sum + i);

  int get successCount => where((d) => d.success).length;

  int get failureCount => where((d) => d.failure).length;

  int get critSuccessCount => where((d) => d.critSuccess).length;

  int get critFailureCount => where((d) => d.critFailure).length;
}

/// [RollResult] represents the result of evaluating a particular node of the AST.
///
class RollResult extends Equatable {
  const RollResult({
    required this.expression,
    required this.opType,
    this.results = const [],
    this.discarded = const [],
    this.left,
    this.right,
  });

  /// factory constructor to merge [other] with the params of this function
  /// and produce a new [RollResult].
  factory RollResult.fromRollResult(
    RollResult other, {
    required String expression,
    OpType? opType,
    List<RolledDie>? results,
    List<RolledDie>? discarded,
    RollResult? left,
    RollResult? right,
  }) => RollResult(
    expression: expression,
    opType: opType ?? other.opType,
    results: results ?? other.results,
    discarded: discarded ?? other.discarded,
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
    results: [RolledDie.singleVal(result: results.sum * other.results.sum)],
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
      RolledDie.singleVal(result: -1 * other.results.sum),
    ],
    discarded: [...other.results.map(RolledDie.discard)],
    left: this,
    right: other,
  );

  /// the parsed expression
  final String expression;

  /// the results of the evaluating the expression
  final List<RolledDie> results;
  final List<RolledDie> discarded;

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
        buffer.write(', results: $results');
      }
      if (discarded.isNotEmpty) {
        buffer.write(', discarded: $discarded');
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
      ..write(pprint(rr.right, indent: '$indent    '));
  }

  return buffer.toString();
}
