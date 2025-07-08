import 'dice_expression.dart';
import 'dice_roller.dart';
import 'enums.dart';
import 'extensions.dart';
import 'roll_result.dart';
import 'rolled_die.dart';
import 'utils.dart';

/// All our operations will inherit from this class.
/// The `call()` method will be called by the parent node.
/// The `eval()` method is called from the node
abstract class DiceOp extends DiceExpression with LoggingMixin {
  // each child class should override this to implement their operation
  Future<RollResult> eval();

  // all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  Future<RollResult> call() async {
    final result = await eval();
    logger.finer(() => '$result');
    return result;
  }
}

/// base class for unary operations
abstract class Unary extends DiceOp {
  Unary(this.name, this.left);

  final String name;
  final DiceExpression left;

  @override
  String toString() => '($left)$name';
}

/// base class for binary operations
abstract class Binary extends DiceOp {
  Binary(this.name, this.left, this.right);

  final String name;
  final DiceExpression left;
  final DiceExpression right;

  @override
  String toString() => '($left $name $right)';
}

class CommaOp extends Binary {
  CommaOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async {
    final lhs = await left();
    final rhs = await right();

    final results = <RolledDie>[];
    final discarded = <RolledDie>[];

    discarded.addAll(lhs.discarded);
    discarded.addAll(rhs.discarded);

    if (lhs.opType == OpType.comma) {
      results.addAll(lhs.results);
    } else {
      results.add(
        RolledDie.singleVal(
          result: lhs.results.sum,
          from: lhs.results,
          totaled: true,
        ),
      );
      discarded.addAll(lhs.results.map(RolledDie.discard));
    }
    if (rhs.opType == OpType.comma) {
      results.addAll(rhs.results);
    } else {
      results.add(
        RolledDie.singleVal(
          result: rhs.results.sum,
          from: rhs.results,
          totaled: true,
        ),
      );
      discarded.addAll(rhs.results.map(RolledDie.discard));
    }

    return RollResult(
      expression: toString(),
      opType: OpType.comma,
      results: results,
      discarded: discarded,
      left: lhs,
      right: rhs,
    );
  }
}

/// multiply operation (flattens results)
class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async => await left() * await right();
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async => await left() + await right();
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  Future<RollResult> eval() async => await left() - await right();
}

/// base class for unary dice operations
abstract class UnaryDice extends Unary {
  UnaryDice(super.name, super.left, this.roller);

  final DiceResultRoller roller;

  @override
  String toString() => '($left$name)';
}

/// base class for binary dice expressions
abstract class BinaryDice extends Binary {
  BinaryDice(super.name, super.left, super.right, this.roller);

  final DiceResultRoller roller;
}

/// A value expression. The token we read from input will be a String,
/// it must parse as an int, and an empty string will return empty set.
class SimpleValue extends DiceExpression {
  SimpleValue(this.value)
    : _results = RollResult(
        expression: value,
        opType: OpType.value,
        results: value.isEmpty
            ? []
            : [RolledDie.singleVal(result: int.parse(value))],
      );

  final String value;
  final RollResult _results;

  @override
  Future<RollResult> call() async => _results;

  @override
  String toString() => value;
}

class AggregateOp extends DiceOp {
  AggregateOp(this.subexpression);

  final DiceExpression subexpression;

  @override
  String toString() => '{$subexpression}';

  @override
  Future<RollResult> eval() async {
    final outcome = await subexpression();

    return RollResult(
      expression: toString(),
      opType: OpType.total,
      results: [
        RolledDie.singleVal(
          result: outcome.results.sum,
          from: outcome.results,
          totaled: true,
        ),
      ],
      discarded: [
        ...outcome.discarded,
        ...outcome.results.map(RolledDie.discard),
      ],
      left: outcome,
    );
  }
}
