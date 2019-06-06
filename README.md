# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)

A library for parsing dice notation

## Supported syntax

Supported notation:
* `AdX` -- roll A dice of X sides, total will be returned as value
* special dice variations:
  * `AdF` -- roll A fudge dice (sides: `[-1, -1, 0, 0, 1, 1]`)
  * `Ad%` -- roll A percentile dice (equivalent to `1d100`)
  * `AD66` -- roll A D66, aka `1d6*10 + 1d6` (NOTE: this _must_ use
    uppercase D, lowercase d will be interpreted as 66-sided die)
* dropping high/low:
  * `AdX-HN` -- roll A X-sided dice, drop N highest
  * `AdX-LN` -- roll A X-sided dice, drop N lowest
  * NOTE: the '-H' and '-L' operators have higher precedence than
    the arithmetic operators, `4d10-L2+2` is equivalent to `(4d10-L2)+2`

* addition/subtraction/multiplication and parenthesis are allowed
* numbers must be integers, and division is is not supported.

examples:
* `2d6 + 1` -- roll two six-sided dice, sum results and add one
* `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
  add that to sum of 3 100-sided die
* `1D66` -- roll a D66 -- aka two six-sided dice, multiply first by 10 and sum results
* `1d%` -- roll one percentile dice
* `4dF` -- roll four fudge dice
* `2d20-H` -- roll 2d20, drop highest (disadvantage)
* `2d20-L` -- roll 2d20, drop lowest (advantage)
* `10d10-L3` -- roll 10d10, drop 10 lowest results

other dice notation info:
* https://en.wikipedia.org/wiki/Dice_notation
* https://itch.io/t/423732/dice-notation

## Usage

A simple usage example:

```dart
    import 'package:dart_dice_parser/dart_dice_parser.dart';

    main() {
      var diceExpression = "2d6 + 1 + 3d10";

      print("$diceExpression : ${roll(diceExpression)}");
    }

    int roll(String diceStr) {
        var result = DiceParser().evaluate(diceStr);

        if (result.isFailure) {
            print("Failure:");
            print('\t${expression}');
            print('\t${' ' * (result.position - 1)}^-- ${result.message}');
            return 1;
        } else {
            return result.value;
        }
    }
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
