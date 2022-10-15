/// A Parser/evalutator for dice notation
///
///
/// Usage example:
/// ```dart
///     int roll(String diceStr) {
///       final factory = DiceExpressionFactory(Random.secure());
///
///       final diceExpr = factory.create('3d6');
///
///       final result1 = diceExpr.roll()
///       final result2 = diceExpr.roll()
///
///     }
/// ```
library dart_dice_parser;

export 'src/dice_expression.dart';
export 'src/dice_roller.dart';
export 'src/parser.dart';
