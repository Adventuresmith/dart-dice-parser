import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

final listEquals = const ListEquality().equals;

/// NOTE: to run w/ asserts: dart run --enable-asserts example/simple.dart

Future<void> main() async {
  Logger.root.level = Level.INFO;

  Logger.root.onRecord.listen((rec) {
    stdout.writeln(
      '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
    );
  });

  // Create a roller for `4d20 kh2 #cf #cs` (roll 4d20, keep highest 2, and track critical success/failure).
  //
  // The following example uses a seeded RNG so that results are the same on every run (so that the asserts below won't fail)
  //
  final d20adv = DiceExpression.create('4d20 kh2 #cf #cs', Random(4321));

  // repeated rolls of the dice expression generate different results
  final result1 = d20adv.roll();
  final result2 = d20adv.roll();

  stdout.writeln(result1);
  stdout.writeln(result2);
  // outputs:
  //  ((((4d20) kh 2) #cf ) #cs ) ===> RollSummary(total: 34, results: [17, 17], metadata: {rolled: [11, 12, 17, 17], discarded: [12, 11]})
  //  ((((4d20) kh 2) #cf ) #cs ) ===> RollSummary(total: 39, results: [20, 19], metadata: {rolled: [1, 12, 19, 20], discarded: [12, 1], score: {critSuccesses: [20]}})

  // demonstrate navigation of the result graph
  assert(result2.total == 39);
  assert(
    listEquals(
      result2.results,
      [20, 19],
    ),
  );
  // read the score-related properties
  assert(!result2.hasSuccesses);
  assert(!result2.hasFailures);
  assert(!result2.hasCritFailures);
  assert(result2.hasCritSuccesses);
  assert(result2.metadata.score.critSuccessesCount == 1);
  assert(
    listEquals(
      result2.metadata.score.critSuccesses,
      [20],
    ),
  );

  // look at the expression tree :
  // ((((4d20) kh 2) #cf ) #cs ) ===> RollSummary(total: 39, results: [20, 19], metadata: {rolled: [1, 12, 19, 20], discarded: [12, 1], score: {critSuccesses: [20]}})
  //   ((((4d20) kh 2) #cf ) #cs ) =count=> RollResult(total: 39, results: [20, 19], metadata: {score: {critSuccesses: [20]}})
  //       (((4d20) kh 2) #cf ) =count=> RollResult(total: 39, results: [20, 19])
  //           ((4d20) kh 2) =drop=> RollResult(total: 39, results: [20, 19], metadata: {discarded: [12, 1]})
  //               (4d20) =rollDice=> RollResult(total: 52, results: [1, 12, 19, 20], metadata: {rolled: [1, 12, 19, 20]})
  // at the top level, it's a 'count' operation that counted the critical success
  final top = result2.detailedResults;
  assert(top.opType == OpType.count);
  assert(
    top.metadata ==
        const RollMetadata(
          score: RollScore(
            critSuccesses: [20],
          ),
        ),
  );
  // next level is the count critical failures node of the graph
  // NOTE: despite there being a 1 rolled, the criticalFailure expression is _after_ the `1` is discarded by the lower expression
  assert(top.left!.opType == OpType.count);
  assert(top.left!.metadata.score.hasCritFailures == false);

  assert(top.left!.left!.opType == OpType.drop);
  assert(
    listEquals(
      top.left!.left!.metadata.discarded,
      [12, 1],
    ),
  );

  assert(top.left!.left!.left!.opType == OpType.rollDice);

  assert(
    listEquals(
      top.left!.left!.left!.results,
      [1, 12, 19, 20],
    ),
  );
  assert(
    listEquals(
      top.left!.left!.left!.metadata.rolled,
      [1, 12, 19, 20],
    ),
  );

  final stats = await DiceExpression.create('2d6', Random(1234)).stats();
  // output:
  //   {mean: 6.99, stddev: 2.4, min: 2, max: 12, count: 1000, histogram: {2: 27, 3: 56, 4: 90, 5: 98, 6: 138, 7: 180, 8: 141, 9: 109, 10: 80, 11: 51, 12: 30}}
  stdout.writeln(stats);
}
