# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)
[![Dart](https://github.com/stevesea/dart-dice-parser/actions/workflows/dart.yml/badge.svg)](https://github.com/stevesea/dart-dice-parser/actions/workflows/dart.yml)
[![codecov](https://codecov.io/gh/stevesea/dart-dice-parser/branch/main/graph/badge.svg?token=YG5OYN9VY1)](https://codecov.io/gh/stevesea/dart-dice-parser)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)


A dart library for parsing dice notation (e.g. "2d6+4"). Supports advantage/disadvantage, exploding die, and other variations.

## Example

```dart

import 'package:dart_dice_parser/dart_dice_parser.dart';

void main() {
  // create a roller for D20 advantage (roll 2d20, drop lowest)
  final dice = DiceExpression.create('2d20-L');
  
  // each roll returns different results.
  final int result1 = dice.roll();
  final int result2 = dice.roll();
}
```

Other examples:

* `2d6 + 1` -- roll two six-sided dice, sum results and add one
* `1D66` -- roll a D66 -- aka two six-sided dice, multiply first by 10 and sum results
* `1d%` -- roll one percentile dice
* `4dF` -- roll four fudge dice
* `2d20-H` -- roll 2d20, drop highest (disadvantage)
* `2d20-L` -- roll 2d20, drop lowest (advantage)
* `4d20-H-L` -- roll 4d20, drop highest and lowest
* `10d10-L3` -- roll 10d10, drop 3 lowest results
* `(2d10+3d20)-L3` -- roll 2d10 and 3d20, combine the two results lists, and drop lowest 3 results
* `20d10-<3->8#` -- roll 20 d10, drop any less than 3 or greater than 8 and count the number of remaining dice
* `2d6 * 3` -- roll 2d6, multiply result by 3
* `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
  add that to sum of 3 100-sided die

## Supported notation
* `AdX` -- roll `A` dice of `X` sides, total will be returned as value
* special dice variations:
  * `AdF` -- roll `A` fudge dice (sides: `[-1, -1, 0, 0, 1, 1]`)
  * `Ad%` -- roll `A` percentile dice (equivalent to `1d100`)
  * `AD66` -- roll `A` D66, aka `1d6*10 + 1d6` (NOTE: you _must_ use
    uppercase `D66`, lowercase `d66` will be interpreted as 66-sided die)

  * exploding dice
    * `Ad!X` -- roll `A` `X`-sided dice, explode if max is rolled (re-roll and include in results)
      * the dice roller won't explode dice more than 100 times.
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
    * `AdX#` -- how many results? (useful for `20d10-<2->8#` -- roll 20 d10, drop <2 and >8, how many are left?)
    * `AdX#>B` -- roll `A` `X`-sided dice, count any greater than B
    * `AdX#<B` -- roll `A` `X`-sided dice, count any less than B
    * `AdX#=B` -- roll `A` `X`-sided dice, count any equal to B
* arithmetic operations
  * parenthesis for order of operations
  * addition is a little special -- could be a sum of ints, or it can be used to aggregate results of multiple dice rolls
    * Addition of integers is the usual sum
      * `4+5` 
      * `2d6 + 1`
    * Addition of roll results combines the results (use parens to ensure the order of operations is as you expect)
      * `(5d6+5d10)-L2` -- roll 5d6 and 5d10, and from aggregate results drop the lowest 2.
      * `5d6+5d10-L2` -- roll 5d6 and 5d10, and from only the 5d10 results drop the lowest 2. equivalent to `5d6+(5d10-L2)`
  * `*` for multiplication
  * numbers must be integers
  * subtraction and division are not supported.
  

### CLI Usage

There's no executable in bin, but there's an example CLI at `example/main.dart`. 

```console
❯ dart example/main.dart '3d6'
1: 10


# run N number of rolls
❯ dart example/main.dart -n6 '3d6'
1: 6
2: 9
3: 11
4: 7
5: 12
6: 12

# show statistics for a roll
❯ dart example/main.dart -s '3d6'
{mean: 10.5, stddev: 2.94, min: 3, max: 18, count: 10000, histogram: {3: 41, 4: 133, 5: 265, 6: 479, 7: 695, 8: 1030, 9: 1211, 10: 1233, 11: 1236, 12: 1164, 13: 938, 14: 658, 15: 446, 16: 278, 17: 157, 18: 36}}


```


# Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
