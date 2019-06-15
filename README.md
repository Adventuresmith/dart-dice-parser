# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)

A library for parsing dice notation

## Supported syntax

### Supported notation
* `AdX` -- roll `A` dice of `X` sides, total will be returned as value
* special dice variations:
  * `AdF` -- roll `A` fudge dice (sides: `[-1, -1, 0, 0, 1, 1]`)
  * `Ad%` -- roll `A` percentile dice (equivalent to `1d100`)
  * `AD66` -- roll `A` D66, aka `1d6*10 + 1d6` (NOTE: this _must_ use
    uppercase D, lowercase d will be interpreted as 66-sided die)

  * exploding dice
    * `Ad!X` -- roll `A` `X`-sided dice, explode if max is rolled (re-roll and include in results)
      * the dice roller won't explode dice more than 1000 times.
    * `Ad!!X` -- roll `A` `X`-sided dice, explode only once (limited explosion)

* modifying the roll results:
  * dropping dice:
    * `AdX-HN` -- roll `A` `X`-sided dice, drop N highest
    * `AdX-LN` -- roll `A` `X`-sided dice, drop N lowest
    * `AdX->B` -- roll `A` `X`-sided dice, drop any results greater than B
    * `AdX-<B` -- roll `A` `X`-sided dice, drop any results less than B
    * `AdX-=B` -- roll `A` `X`-sided dice, drop any results equal to B
    * NOTE: the drop operators have higher precedence than
      the arithmetic operators, so `4d10-L2+2` is equivalent to `(4d10-L2)+2`
  * cap/clamp:
    * `AdXC<B` -- roll `A` `X`-sided dice, change any value less than B to B
    * `AdXC>B` -- roll `A` `X`-sided dice, change any value greater than B to B
* operations on dice rolls:
  * counting:
    * `AdX#` -- how many are in the results? (useful for `20d10-<2->8#` -- roll 20 d10, drop <2 and >8, how many are left?)
    * `AdX#>B` -- roll `A` `X`-sided dice, count any greater than B
    * `AdX#<B` -- roll `A` `X`-sided dice, count any less than B
    * `AdX#=B` -- roll `A` `X`-sided dice, count any equal to B
* addition/subtraction/multiplication and parenthesis are allowed
* numbers must be integers, and division is is not supported.


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
* `20d10-<3->8#` -- roll 20 d10, drop any less than 3 or greater than 8 and count the number of remaining dice

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
foo@bar$ pub run example/main.dart  "3d6"
1, 9

# run N number of rolls
foo@bar$ pub run example/main.dart -n 6 "3d6"
1, 6
2, 8
3, 15
4, 15
5, 8
6, 10

# show stats
foo@bar$ pub run example/main.dart -s "3d6"
{count: 1000, mean: 10.5, median: 10.0, max: 18, min: 3, standardDeviation: 2.95, histogram: {3: 3, 4: 14, 5: 25, 6: 50, 7: 72, 8: 107, 9: 105, 10: 146, 11: 121, 12: 101, 13: 87, 14: 76, 15: 48, 16: 27, 17: 14, 18: 4}}

# increase verbositoy to show what's going on under the hood:
foo@bar$ pub run example/main.dart  -v "4d10-H + 2d6"
[FINE] main: Evaluating: 4d10-H + 2d6 => Success[1:13]: [[[4, d, 10], -H, null], +, [2, d, 6]]

[FINEST] DiceRoller: roll 4d10 => [7, 7, 3, 9]
[FINER] DiceParser: 4d10 => [7, 7, 3, 9]
[FINER] DiceParser: [7, 7, 3, 9]-H1 => [7, 7, 3] (dropped: [9])
[FINEST] DiceRoller: roll 2d6 => [5, 1]
[FINER] DiceParser: 2d6 => [5, 1]
[FINER] DiceParser: [7, 7, 3]+[5, 1] => [7, 7, 3, 5, 1]
1, 23

# explode some dice
foo@bar$ pub run example/main.dart  -v "12d\!6"
[FINE] main: Evaluating: 12d!6 => Success[1:6]: [12, d!, 6]

[FINEST] DiceRoller: roll 12d6 => [2, 6, 3, 1, 1, 6, 3, 2, 2, 1, 6, 3]
[FINEST] DiceRoller: explode 3 !
[FINEST] DiceRoller: roll 3d6 => [2, 1, 6]
[FINEST] DiceRoller: explode 1 !
[FINEST] DiceRoller: roll 1d6 => [3]
[FINEST] DiceRoller: roll 12d6 => [2, 6, 3, 1, 1, 6, 3, 2, 2, 1, 6, 3, 2, 1, 6, 3]
[FINER] DiceParser: 12d!6 => [2, 6, 3, 1, 1, 6, 3, 2, 2, 1, 6, 3, 2, 1, 6, 3]
1, 48

# roll, explode, drop, count
foo@bar$ pub run example/main.dart  -v "(4d8)d\!4-<4#"
[FINE] main: Evaluating: (4d8)d!4-<4# => Success[1:13]: [[[[(, [4, d, 8], )], d!, 4], -<, 4], #]

[FINEST] DiceRoller: roll 4d8 => [5, 1, 7, 3]
[FINER] DiceParser: 4d8 => [5, 1, 7, 3]
[FINEST] DiceRoller: roll 16d4 => [2, 4, 1, 2, 2, 2, 3, 1, 1, 3, 4, 3, 2, 4, 3, 3]
[FINEST] DiceRoller: explode 3 !
[FINEST] DiceRoller: roll 3d4 => [4, 2, 1]
[FINEST] DiceRoller: explode 1 !
[FINEST] DiceRoller: roll 1d4 => [1]
[FINEST] DiceRoller: roll 16d!4 => [2, 4, 1, 2, 2, 2, 3, 1, 1, 3, 4, 3, 2, 4, 3, 3, 4, 2, 1, 1]
[FINER] DiceParser: [5, 1, 7, 3]d!4 => [2, 4, 1, 2, 2, 2, 3, 1, 1, 3, 4, 3, 2, 4, 3, 3, 4, 2, 1, 1]
[FINER] DiceParser: [2, 4, 1, 2, 2, 2, 3, 1, 1, 3, 4, 3, 2, 4, 3, 3, 4, 2, 1, 1]-<4 => [4, 4, 4, 4] (dropped: [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3])
[FINER] DiceParser: [4, 4, 4, 4]#1 => 4
1, 4

# when I roll 100d!10, how many 10's do I get? (try 10000 times and show me stats)
foo@bar$ pub run example/main.dart -s "100d\!10#=10" -n 10000
{count: 10000, mean: 11.1, median: 11.0, max: 25, min: 1, standardDeviation: 3.5, histogram: {1: 5, 2: 15, 3: 46, 4: 97, 5: 238, 6: 451, 7: 667, 8: 826, 9: 1027, 10: 1082, 11: 1175, 12: 1069, 13: 912, 14: 736, 15: 550, 16: 398, 17: 266, 18: 184, 19: 121, 20: 70, 21: 28, 22: 17, 23: 13, 24: 6, 25: 1}}
```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
