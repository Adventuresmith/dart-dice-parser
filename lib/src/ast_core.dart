import 'dice_expression.dart';
import 'dice_roller.dart';
import 'results.dart';
import 'utils.dart';

/// All our operations will inherit from this class.
/// The `call()` method will be called by the parent node.
/// The `eval()` method is called from the node
abstract class DiceOp extends DiceExpression with LoggingMixin {
  // each child class should override this to implement their operation
  RollResult eval();

  // all children can share this call operator -- and it'll let us be consistent w/ regard to logging
  @override
  RollResult call() {
    final result = eval();
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

/// multiply operation (flattens results)
class MultiplyOp extends Binary {
  MultiplyOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() * right();
}

/// add operation
class AddOp extends Binary {
  AddOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() + right();
}

/// subtraction operation
class SubOp extends Binary {
  SubOp(super.name, super.left, super.right);

  @override
  RollResult eval() => left() - right();
}

/// base class for unary dice operations
abstract class UnaryDice extends Unary {
  UnaryDice(super.name, super.left, this.roller);

  final DiceRoller roller;

  @override
  String toString() => '($left$name)';
}

/// base class for binary dice expressions
abstract class BinaryDice extends Binary {
  BinaryDice(super.name, super.left, super.right, this.roller);

  final DiceRoller roller;
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
  RollResult call() => _results;

  @override
  String toString() => value;
}
