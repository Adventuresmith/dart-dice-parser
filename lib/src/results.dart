import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class ResultStream {
  factory ResultStream() => _singleton;
  ResultStream._internal();

  static final _singleton = ResultStream._internal();
  static final _logger = Logger('ResultStream');

  final _controller = StreamController<String>.broadcast(
    onCancel: () => _logger.finest('Cancelled'),
    onListen: () => _logger.finest('Listens'),
  );
  Stream<String> get stream => _controller.stream;

  void publish(String event) => _controller.add(event);
}

@immutable
class RollResult extends Equatable {
  const RollResult({required this.name, required this.value});

  final String name;
  final int value;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [
        name,
        value,
      ];

  int get length => 1;

  RollResult operator +(RollResult other) {
    return RollResult(
      name: "$name + ${other.name}",
      value: value + other.value,
    );
  }
}

class DiceRollResult extends RollResult {
  const DiceRollResult({
    required super.name,
    required super.value,
    required this.ndice,
    required this.nsides,
    required this.rolls,
    this.allowAdditionalOps = true,
  });
  final int ndice;
  final int nsides;
  final List<int> rolls;
  final bool allowAdditionalOps;

  @override
  List<Object?> get props => [
        name,
        value,
        ndice,
        nsides,
        rolls,
        allowAdditionalOps,
      ];

  @override
  int get length => rolls.length;

  @override
  RollResult operator +(RollResult other) {
    if (other is FudgeRollResult) {
      throw ArgumentError("Cannot combine fudge and other dice");
    }
    if (other is DiceRollResult) {
      if (nsides == other.nsides) {
        return DiceRollResult(
          name: "$name + ${other.name}",
          value: value + other.value,
          ndice: ndice + other.ndice,
          nsides: nsides,
          rolls: rolls + other.rolls,
        );
      } else {
        return DiceRollResult(
          name: "$name + ${other.name}",
          value: value + other.value,
          ndice: ndice + other.ndice,
          nsides: 0,
          rolls: rolls + other.rolls,
          allowAdditionalOps: false,
        );
      }
    } else {
      return RollResult(
        name: "$name + ${other.name}",
        value: value + other.value,
      );
    }
  }
}

class FudgeRollResult extends RollResult {
  const FudgeRollResult({
    required super.name,
    required super.value,
    required this.ndice,
    required this.rolls,
  });
  final int ndice;
  final List<int> rolls;

  @override
  List<Object?> get props => [
        name,
        value,
        ndice,
        rolls,
      ];

  @override
  int get length => rolls.length;

  @override
  RollResult operator +(RollResult other) {
    if (other is DiceRollResult) {
      throw ArgumentError("Cannot combine fudge and other dice");
    }
    if (other is FudgeRollResult) {
      return FudgeRollResult(
        name: "$name + ${other.name}",
        value: value + other.value,
        ndice: ndice + other.ndice,
        rolls: rolls + other.rolls,
      );
    } else {
      return RollResult(
        name: "$name + ${other.name}",
        value: value + other.value,
      );
    }
  }
}
