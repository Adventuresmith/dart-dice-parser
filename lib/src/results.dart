import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

class ResultStream {
  factory ResultStream() => _singleton;
  ResultStream._internal();

  static final _singleton = ResultStream._internal();
  static final _logger = Logger('ResultStream');

  final _controller = StreamController<String>(
    onCancel: () => _logger.finest('Cancelled'),
    onListen: () => _logger.finest('Listens'),
  );
  Stream<String> get stream => _controller.stream;

  void publish(String event) => _controller.add(event);
}

enum OperationType {
  /// integer value
  value,
  add,
  subtract,
  multiply,
  count,
  drop,
  dropHighLow,
  clamp,
  dice,
  diceFudge,
  dice66,
  reroll,
  compound,
  explode,
}

///
class RollResult {
  RollResult({
    required this.expression,
    required this.operation,
    required this.operationType,
    this.ndice = 0,
    this.nsides = 0,
    this.rolled = const [],
    this.dropped = const [],
    this.metadata = const {},
    this.left,
    this.right,
  }) {
    total = rolled.sum;
  }

  int total = 0;
  final String expression;
  final String operation;
  final OperationType operationType;
  final int nsides;
  final int ndice;
  final List<int> rolled;
  final List<int> dropped;
  final Map<String, Object> metadata;
  final RollResult? left;
  final RollResult? right;

  static int _defaultCb() => throw ArgumentError("missing value");

  /// Evaluate this roll result (generally, sum the rolls).
  /// However, if result is a Value and empty, return result of calling [defaultCb].
  /// if [defaultCb] not provided, 0 will be returned.
  int resolveToInt([int Function() defaultCb = _defaultCb]) {
    if (operationType == OperationType.value && rolled.isEmpty) {
      return defaultCb();
    }
    return rolled.sum;
  }

  @override
  String toString() {
    return 'RollResult(expr: $expression, rolled: $rolled, dropped: $dropped, total: $total)';
  }
}
