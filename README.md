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
  // Create a roller for D20 advantage (roll 2d20, keep highest).
  final d20adv = DiceExpression.create('2d20 kh', Random());

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 15, results: [15] , metadata: {dropped: [8], rolled: [8, 15]})

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 20, results: [20] , metadata: {dropped: [5], rolled: [5, 20]})
}
```

Other examples:

* `2d6 + 1` -- roll two six-sided dice, sum results and add one
* `1D66` -- roll a D66 -- aka two six-sided dice, multiply first by 10 and sum results
* `1d%` -- roll one percentile dice
* `4dF` -- roll four fudge dice
* `2d20-H` -- roll 2d20, drop highest (disadvantage)
  * equivalent to `2d20k` or `2d20kh` or `2d20k1` (keep high)
* `2d20-L` -- roll 2d20, drop lowest (advantage)
  * equivalent to `2d20kl` or `2d20kl1`
* `4d20-H-L` -- roll 4d20, drop highest and lowest
* `10d10-L3` -- roll 10d10, drop 3 lowest results
* `(2d10+3d20)-L3` -- roll 2d10 and 3d20, combine the two results lists, and drop lowest 3 results
* `20d10-<3->8#` -- roll 20 d10, drop any less than 3 or greater than 8 and count the number of remaining dice
* `2d6 * 3` -- roll 2d6, multiply result by 3
* `2d(2*10) + 3d100` -- roll 2 twenty-sided dice, sum results,
  add that to sum of 3 100-sided die

## Random Number Generator

By default, Random.secure() is used. You can select other RNGs at when creating the
dice expression. Random.secure() is much slower, so if you're doing lots of rolls
for a use case where security doesn't matter, you may want to use Random() instead.

```dart 
  // uses Random.secure()
  final diceExpr1 = DiceExpression.create('2d20 kh');
  
  // uses supplied RNG.
  final diceExpr2 = DiceExpression.create('2d20 kh', Random());

```

## Supported notation
* `AdX` -- roll `A` dice of `X` sides
* special dice variations:
  * `AdF` -- roll `A` fudge dice (sides: `[-1, -1, 0, 0, 1, 1]`)
  * `Ad%` -- roll `A` percentile dice (equivalent to `1d100`)
  * `AD66` -- roll `A` D66, aka `1d6*10 + 1d6` (NOTE: you _must_ use
    uppercase `D66`, lowercase `d66` will be interpreted as 66-sided die)
  
* modifying the roll results:
  * exploding dice
    * `AdX!` -- roll `A` `X`-sided dice, explode if max (`X`) is rolled (re-roll and include in results)
      * `AdX!=N` or `AdX!N` -- explode a roll if equal to N (default X)
      * `AdX!>=N` - explode if >= N
      * `AdX!<=N` - explode if >= N
      * `AdX!>N` - explode if > N
      * `AdX!<N` - explode if > N
      * To limit to a single explode, use syntax `!o` (otherwise, dice rolls explode at most 1000 times)
        * `AdX!o<N`
  * compounding dice (Shadowrun, L5R, etc). Similar to exploding, but the additional rolls for each
    dice are added together as a single "roll"
    * `AdX!!` -- roll `A` `X`-sided dice, compound
      * `AdX!!=N` or `AdX!N` -- compound a roll if equal to N (default X)
      * `AdX!!>=N` - compound if >= N
      * `AdX!!<=N` - compound if >= N
      * `AdX!!>N` - compound if > N
      * `AdX!!<N` - compound if > N
      * To limit to a single compound, use syntax `!!o` (otherwise, dice rolls compound at most 1000 times)
        * `AdX!!o<N`
  * re-rolling dice:
    * `AdX rN` -- roll `A` `X`-sided dice, re-roll any N
    * `AdX r=N` -- roll `A` `X`-sided dice, re-roll any N
    * `AdX r<=N` -- roll `A` `X`-sided dice, re-roll any <= N
    * `AdX r>=N` -- roll `A` `X`-sided dice, re-roll any >= N
    * `AdX r<N` -- roll `A` `X`-sided dice, re-roll any < N
    * `AdX r>N` -- roll `A` `X`-sided dice, re-roll any > N
    * To limit to a single reroll, use syntax `!!o` (otherwise, dice rolls reroll at most 1000 times)
      * `AdX!!o<N`
  * keeping dice:
    * `AdX k N` -- roll `A` `X`-sided dice, keep N highest
    * `AdX kh N` -- roll `A` `X`-sided dice, keep N highest
    * `AdX kl N` -- roll `A` `X`-sided dice, keep N lowest
  * dropping dice:
    * `AdX-HN` -- roll `A` `X`-sided dice, drop N highest
    * `AdX-LN` -- roll `A` `X`-sided dice, drop N lowest
    * `AdX->B` -- roll `A` `X`-sided dice, drop any results > B
    * `AdX-<B` -- roll `A` `X`-sided dice, drop any results < B
    * `AdX->=B` -- roll `A` `X`-sided dice, drop any results >= B
    * `AdX-<=B` -- roll `A` `X`-sided dice, drop any results <= B
    * `AdX-=B` -- roll `A` `X`-sided dice, drop any results equal to B
    * NOTE: the drop operators have higher precedence than
      the arithmetic operators; `4d10-L2+2` is equivalent to `(4d10-L2)+2`
  * cap/clamp:
    * `AdX C<B` -- roll `A` `X`-sided dice, change any value < B to B
    * `AdX C>B` -- roll `A` `X`-sided dice, change any value > B to B
* operations on dice rolls:
  * counting:
    * `AdX #` -- how many results? 
      * For example, you might use this to count # of dice above a target. `5d10-<6` -- roll 5 d10, drop any 5 or under, count results
    * `AdX #>B` -- roll `A` `X`-sided dice, count any greater than B
    * `AdX #<B` -- roll `A` `X`-sided dice, count any less than B
    * `AdX #>=B` -- roll `A` `X`-sided dice, count any greater than or equal to B
    * `AdX #<=B` -- roll `A` `X`-sided dice, count any less than or equal to B
    * `AdX #=B` -- roll `A` `X`-sided dice, count any equal to B
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
