# 5.1.1
- add syntax for exploding/compounding/reroll once
  - `4d6 !o`
  - `4d6 !!o`
  - `4d6 ro`
- add syntax for success, failure, as well as crit success & failure.
  - `4d6 #s=6`
  - plain `#` counts results and transforms the expression from rolls into a count.
  - but `#s`, `#f`, `#cs`, `#cf` only add metadata to the roll result, and can be chained together.
    - `9d6! -= 3 #s>=5#f1#cs` -- roll 9d6 with exploding, drop any threes, count >=5 as success, 1s as failures, and 6 as critical success

# 5.1.0
- make RollResult aggregate _all_ results for whole AST

# 5.0.0
- add compounding dice: `5d6!!`
- add keep high/low: `2d20k`
- add reroll: `10d4 r<=2`
- allow exploding/compounding dice to have an rhs expression (>=,<=,=,<,>)
- remove `!!` as 'limited explosion' (make it compounding, like Roll20 dice notation)
- fix syntax for exploding dice (2d6!, not 2d!6). 
- remove exploding method from DiceRoller -- now it's part of the AST. 
- dice rolls return RollResult
- clean up redundant parser config

# 4.1.0
- cleanup examples
- add syntax for `>=` and `<=` for counts, drop, clamp
- remove redundancy in parser defintion

# 4.0.6
- allow subtraction

# 4.0.5
- remove unused dev dependency

# 4.0.4
- fix typo in unit test

# 4.0.3
- increase test coverage -- test rollN and stats.

# 4.0.1
- add github actions, remove circleci
- add codecov

# 4.0.0
- cleanup petitparser usage -- generate AST so that parsing the dice expression can be separate from rolling dice.

# 3.1.0
- remove subtraction
- clean up add/mult -- don't collapse lists to ints
  - `[1,4,5] + 2` => `[1,4,5,2]`
  - `[1,4,5] * 2` => `[2,8,10]`
- remove subtraction -- like division, too many corner cases
- clean up error handling -- throw less often, less complex if/else statements.

# 3.0.3
- update linter and fix analysis 

# 3.0.2
- fix circleci build

# 3.0.1
- minor analysis cleanup (dead code)

# 3.0.0
- upgrade deps & null safety
- more error handling

# 2.0.1
- downgrade petitparser

# 2.0.0
- library upgrades including sdk >2.7.0

# 1.4.2
- use unmodifiable view return types

# 1.4.1
- fix return types of stats objects

# 1.4.0
- replace use of stats library w/ implementation of welford's algorithm.
  see http://alias-i.com/lingpipe/docs/api/com/aliasi/stats/OnlineNormalEstimator.html
- make DiceParser.rollN an async generator returning stream of results

# 1.3.6
- allow lowercase for `-H`, `-L`, `C>`, `C<`

# 1.3.5
- back off petitparser dependency -- back off to 2.2.1,
  so that we don't have dependency on Dart 2.3.0
  (current stable flutter is 2.3.0-dev)

# 1.3.4
- make code more idiomatic

# 1.3.3
- make log fields non-public

# 1.3.2
- upgrade mockito dep

# 1.3.0
- add drop equals/less-than/greater-than
- add cap/clamp
- add counting operation
- add exploding dice

# 1.2.2
- more logging and error handling cleanup

# 1.2.1
- more logging and error handling cleanup

# 1.2.0
- add dice stats to the parser
- logging & error handling cleanup

# 1.1.2
- more tests and cleanup examples

# 1.1.1
- fix typo in readme

# 1.1.0
- add drop high/low parsing

# 1.0.2
- fix readme example

# 1.0.1
- fix readme issues

# 1.0.0
- bump min dart SDK to 2.2.2
- cleanup parser code
- cleanup analysis problems
- add percentile and D66 dice
- handle missing A or X in AdX
- flesh out API docs

# 0.2.2
- reformat

# 0.2.1
- upgrade some dependencies

# 0.2.0
- upgrade to dart 2

# 0.1.2

- move args to dev_dependency, since it's just for the example

# 0.1.1

- added contributing/code-of-conduct docs

# 0.1.0

- change DiceRoller to output information about individual rolls, instead of just returning the sum.

# 0.0.6

- remove dependency on quiver, since not heavily using it

# 0.0.5

- various fixes as I figure out what I'm doing with Dart
- empty/null checking with quiver.strings

# 0.0.1

- Initial version, created by Steve Christensen

