# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)

A library for parsing dice notation

## Supported syntax

### Supported notation
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
    the arithmetic operators, so `4d10-L2+2` is equivalent to `(4d10-L2)+2`

* addition/subtraction/multiplication and parenthesis are allowed
* numbers must be integers, and division is is not supported.

TODO:
* exploding dice
  * for this to work, need to pass along info about dice up to parser (to know which is max#)... or, could do
     `3d10!=10` (explode if equal 10)
* drop conditionally
  * 3d10-<3 drop any less than 3
  * 3d10->3 drop any greater than 3
  * 3d10-=3 drop any equal 3
* cap/clamp
  * 3d10C<3 treat any value less than 3 as 3
  * 3d10C>3 treat any value greater than 3 as 3
* count
  * 3d10# -- count how many have maximum
  * 3d10#>6 -- count how many are greater than 6
  * 3d10#=7 -- count how many are equal to 7
  * 3d10#<3 -- count how many are less than 3

### Examples
* `2d6 + 1` -- roll two six-sided dice, sum results and add one
* `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
  add that to sum of 3 100-sided die
* `1D66` -- roll a D66 -- aka two six-sided dice, multiply first by 10 and sum results
* `1d%` -- roll one percentile dice
* `4dF` -- roll four fudge dice
* `2d20-H` -- roll 2d20, drop highest (disadvantage)
* `2d20-L` -- roll 2d20, drop lowest (advantage)
* `10d10-L3` -- roll 10d10, drop 3 lowest results
* `(2d10+3d20)-L3` -- roll 2d10 and 3d20, combine the two results lists and drop lowest 3 rolls

## Usage

A simple usage example:

```dart
    import 'package:dart_dice_parser/dart_dice_parser.dart';

    main() {
      var diceExpression = "2d6 + 1 + 3d10";

      print("$diceExpression : ${DiceParser().roll(diceExpression)}");
    }

```

### CLI Usage

```console
foo@bar$ pub run example/dart_dice_parser.dart  "3d6"
1, 9

# run N number of rolls
foo@bar$ pub run example/dart_dice_parser.dart -n 6 "3d6"
1, 6
2, 8
3, 15
4, 15
5, 8
6, 10

# show stats
foo@bar$ pub run example/dart_dice_parser.dart -s "3d6"
{count: 1000, mean: 10.5, median: 10.0, max: 18, min: 3, standardDeviation: 2.95, histogram: {3: 3, 4: 14, 5: 25, 6: 50, 7: 72, 8: 107, 9: 105, 10: 146, 11: 121, 12: 101, 13: 87, 14: 76, 15: 48, 16: 27, 17: 14, 18: 4}}

# increase verbositoy to show what's going on under the hood:
foo@bar$ pub run example/dart_dice_parser.dart  -v "4d10-H + 2d6"
[FINE] main: Evaluating: 4d10-H + 2d6 => Success[1:13]: [[[4, d, 10], -H, null], +, [2, d, 6]]

[FINEST] DiceRoller: roll 4d10 => [7, 7, 3, 9]
[FINER] DiceParser: 4d10 => [7, 7, 3, 9]
[FINER] DiceParser: [7, 7, 3, 9]-H1 => [7, 7, 3] (dropped: [9])
[FINEST] DiceRoller: roll 2d6 => [5, 1]
[FINER] DiceParser: 2d6 => [5, 1]
[FINER] DiceParser: [7, 7, 3]+[5, 1] => [7, 7, 3, 5, 1]
1, 23


```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
