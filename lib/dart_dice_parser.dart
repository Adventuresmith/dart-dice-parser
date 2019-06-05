
/// A Parser/evalutator for dice notation
///
/// Supported notation:
/// * `AdX` -- roll A dice of X sides, total will be returned as value
/// * special handling:
///   * `Ad%` -- roll A percentile dice (100-sided)
///   * `AD66` -- roll A D66, aka `1d6*10 + 1d6`
/// * addition/subtraction/multiplication and parenthesis are allowed
///   * `2d6 + 1` -- roll two six-sided dice, sum results and add one
///   * `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
///     add that to sum of 3 100-sided die
/// * numbers must be integers, and division is is not supported.
///
/// Usage example:
///
///     int roll(String diceStr) {
///       var result = DiceParser().evaluate(diceStr);
///
///       if (result.isFailure) {
///         print("Failure:");
///         print('\t{expression}');
///         print('\t${' ' * (result.position - 1)}^-- ${result.message}');
///         return 1;
///       } else {
///         return result.value;
///       }
///     }
library dart_dice_parser;

export 'src/dice_parser.dart';

export 'src/dice_roller.dart';
