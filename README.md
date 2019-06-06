# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)

A library for parsing dice notation

## Supported syntax

Supported notation:
* `AdX` -- roll A dice of X sides, total will be returned as value
* special dice variations:
  * `AdF` -- roll A fudge dice
  * `Ad%` -- roll A percentile dice (100-sided)
  * `AD66` -- roll A D66, aka `1d6*10 + 1d6`
    * NOTE: this _must_ use uppercase D
* addition/subtraction/multiplication and parenthesis are allowed
  * `2d6 + 1` -- roll two six-sided dice, sum results and add one
  * `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
    add that to sum of 3 100-sided die
* numbers must be integers, and division is is not supported.

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
