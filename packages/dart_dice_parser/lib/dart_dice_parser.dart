/// A Parser for dice notation
///
///
/// Usage example:
///
/// ```dart
/// const input = '2d20-L'; // D20 advantage -- roll 2d20, drop lowest
/// final diceExpr = DiceExpression.create(input);
/// for (var i = 0; i < 2; i++) {
///   final int result = await diceExpr.roll();
///   stdout.writeln("$i : $result");
/// }
/// ```
library;

export 'src/dice_expression.dart';
export 'src/dice_roller.dart';
export 'src/enums.dart';
export 'src/extensions.dart';
export 'src/roll_result.dart';
export 'src/roll_summary.dart';
export 'src/rolled_die.dart';
