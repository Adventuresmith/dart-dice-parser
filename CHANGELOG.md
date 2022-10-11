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

