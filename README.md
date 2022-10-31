# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)
[![Dart](https://github.com/stevesea/dart-dice-parser/actions/workflows/dart.yml/badge.svg)](https://github.com/stevesea/dart-dice-parser/actions/workflows/dart.yml)
[![codecov](https://codecov.io/gh/stevesea/dart-dice-parser/branch/main/graph/badge.svg?token=YG5OYN9VY1)](https://codecov.io/gh/stevesea/dart-dice-parser)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)


A dart library for parsing dice notation (e.g. "2d6+4"). Supports advantage/disadvantage, exploding die, and other variations.

# Example

```dart

import 'package:dart_dice_parser/dart_dice_parser.dart';

void main() {
  // Create a roller for D20 advantage (roll 2d20, keep highest).
  final d20adv = DiceExpression.create('2d20 kh');

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 15, results: [15] , metadata: {dropped: [8], rolled: [8, 15]})

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 20, results: [20] , metadata: {dropped: [5], rolled: [5, 20]})
}
```

## Random Number Generator

By default, Random.secure() is used. You can select other RNGs at when creating the
dice expression. Random.secure() is slower, so if you're doing lots of rolls
for use cases where security doesn't matter, you may want to use Random() instead.

```dart 
  // uses Random.secure()
  final diceExpr1 = DiceExpression.create('2d20 kh');
  
  // uses supplied RNG.
  final diceExpr2 = DiceExpression.create('2d20 kh', Random());

```

# Dice Notation

## Examples:

* `1d20 #cf #cs`
  * roll 1d20, result will include counts of successes, failures (1)

* advantage/disadvantage in 5E
  * There's a couple ways to roll advantage
    * `2d20-L` -- roll 2d20, drop lowest (advantage)
    * `2d20k`, `2d20kh` -- roll 2d20 keep highest
  * Similarly for disadvantage:
    * `2d20-H` -- drop highest
    * `2d20-kl` -- keep lowest
* `(2d10+3d20)-L3` -- roll 2d10 and 3d20, combine the two results lists, and drop lowest 3 results
* `20d10-<3->8#` -- roll 20 d10, drop any less than 3 or greater than 8 and count the number of remaining dice


## Supported notation

* `2d6` -- roll `2` dice of `6` sides
* special dice variations:
  * `4dF` -- roll `4` fudge dice (sides: `[-1, -1, 0, 0, 1, 1]`)
  * `1d%` -- roll `1` percentile dice (equivalent to `1d100`)
  * `1D66` -- roll `1` D66, aka `1d6*10 + 1d6` 
    * **_NOTE_**: you _must_ use uppercase `D66`, lowercase `d66` will be interpreted as 66-sided die
  
* exploding dice
  * `4d6!` -- roll `4` `6`-sided dice, explode if max (`6`) is rolled (re-roll and include in results)
    * `4d6!=5` or `4d6!5` -- explode a roll if equal to 5 
    * `4d6!>=4` - explode if >= 4
    * `4d6!<=2` - explode if <=2
    * `4d6!>5` - explode if > 5
    * `4d6!<2` - explode if <2
    * To limit to a single explosion, use syntax `!o` (otherwise, dice rolls will explode at most 1000 times)
      * `4d6!o<5`
* compounding dice (Shadowrun, L5R, etc). Similar to exploding, but the additional rolls for each
  dice are added together as a single "roll"
  * `5d6!!` -- roll `5` `6`-sided dice, compound
    * `5d6!!=5` or `5d6!5` -- compound a roll if equal to 5 
    * `5d6!!>=4` - compound if >= 4
    * `5d6!!<=4` - compound if <= 4
    * `5d6!!>5` - compound if > 5
    * `5d6!!<3` - compound if < 3
    * To limit to a single compound, use syntax `!!o` (otherwise, dice rolls compound at most 1000 times)
      * `5d6!!o<2`
* re-rolling dice:
  * `4d4 r2` -- roll 4d4, re-roll any result = 2
  * `4d4 r=2` -- roll 4d4, re-roll any result = 2
  * `4d4 r<=2` -- roll 4d4, re-roll any <= 2
  * `4d4 r>=3` -- roll 4d4, re-roll any >= 3
  * `4d4 r<2` -- roll 4d4, re-roll any < 2
  * `4d4 r>3` -- roll 4d4, re-roll any > 3
  * To limit to a single reroll, use syntax `!!o` (otherwise, dice rolls reroll at most 1000 times)
    * `4d4!!o<2`
* keeping dice:
  * `3d20 k 2` -- roll 3d20, keep 2 highest
  * `3d20 kh 2` -- roll 3d20, keep 2 highest
  * `3d20 kl 2` -- roll 3d20, keep 2 lowest
* dropping dice:
  * `4d6 -H` -- roll 4d6, drop 1 highest
  * `4d6 -L` -- roll 4d6, drop 1 lowest
  * `4d6 -H2` -- roll 4d6, drop 2 highest
  * `4d6 -L2` -- roll 4d6, drop 2 lowest
  * `4d6 ->5` -- roll 4d6, drop any results > 5
  * `4d6 -<2` -- roll 4d6, drop any results < 2
  * `4d6 ->=5` -- roll 4d6, drop any results >= 5
  * `4d6 -<=2` -- roll 4d6, drop any results <= 2
  * `4d6 -=1` -- roll 4d6, drop any results equal to 1
  * NOTE: the drop operators have higher precedence than
    the arithmetic operators; `4d10-L2+2` is equivalent to `(4d10-L2)+2`
  * cap/clamp:
    * `4d20 C<5` -- roll 4d20, change any value < 5 to 5
    * `4d20 C>15` -- roll 4d20, change any value > 15 to 15
* operations on dice rolls:
  * counting:
    * `4d6 #` -- how many results? 
      * For example, you might use this to count # of dice above a target. `(5d10-<6)#` -- roll 5 d10, drop any 5 or under, count results
    * `4d6 #>3` -- roll 4d6, count any > 3
    * `4d6 #<3` -- roll 4d6, count any < 3
    * `4d6 #>=5` -- roll 4d6, count any >= 5
    * `4d6 #<=2` -- roll 4d6, count any <= 2
    * `4d6 #=5` -- roll 4d6, count any equal to 5
  * counting (critical) success/failures 
    * A normal count operation `#` discards the rolled dice and changes the result to be the count
      * For example, `2d6#<=3` rolls `[3,4]` then counts which results are `<=3` , returning `[1]`
    * But, sometimes you want to be able to count successes/failures without discarding the rolls. 
      In this case, use modifiers `#s`, `#f`, `#cs`, `#cf` to add metadata to the results.
      * `6d6 #f<=2#s>=5#cs6` -- roll 6d6, count results <= 2 as failures, >= 5 as successes, and =6 as critical successes.
        * returns a result like: `RollResult(total: 22, results: [6, 2, 1, 5, 3, 5] {failures: {count: 2, target: #f<=2}, successes: {count: 3, target: #s>=5}, critSuccesses: {count: 1, target: #cs6}})`
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
  * `-` for subtraction
  * numbers must be integers
  * division is not supported.
  

### CLI Usage

There's no executable in bin, but there's an example CLI at `example/main.dart`. 

```console
❯ dart example/main.dart '3d6'
(3d6) => RollResult(total: 9, results: [4, 3, 2])


# run N number of rolls
❯ dart example/main.dart -n6 '3d6'
(3d6) => RollResult(total: 14, results: [6, 6, 2])
(3d6) => RollResult(total: 8, results: [2, 5, 1])
(3d6) => RollResult(total: 12, results: [3, 5, 4])
(3d6) => RollResult(total: 16, results: [5, 5, 6])
(3d6) => RollResult(total: 15, results: [3, 6, 6])
(3d6) => RollResult(total: 6, results: [1, 1, 4])


# show statistics for a dice expression
❯ dart example/main.dart  -s '3d6'
{mean: 10.5, stddev: 2.97, min: 3, max: 18, count: 10000, histogram: {3: 49, 4: 121, 5: 273, 6: 461, 7: 727, 8: 961, 9: 1153, 10: 1182, 11: 1272, 12: 1151, 13: 952, 14: 733, 15: 486, 16: 289, 17: 154, 18: 36}}

```


# Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
