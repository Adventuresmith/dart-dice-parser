/// A Parser/evalutator for dice notation
///
///
/// Usage example:
/// ```dart
///     int roll(String diceStr) {
///       var result = DiceParser().evaluate(diceStr);
///
///       if (result.isFailure) {
///         print("Failure:");
///         print('\t${expression}');
///         print('\t${' ' * (result.position - 1)}^-- ${result.message}');
///         return 1;
///       } else {
///         return result.value;
///       }
///     }
/// ```
library dart_dice_parser;

export 'src/ast.dart';
export 'src/dice_parser.dart';
export 'src/dice_roller.dart';
