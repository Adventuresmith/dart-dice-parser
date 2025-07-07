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
  final d20adv = DiceExpression.create(
    '4d20 kh2 #cf #cs',
    roller: RNGRoller(Random(4321)),
  );

  // repeated rolls of the dice expression generate different results
  final result1 = await d20adv.roll();
  final result2 = await d20adv.roll();

  stdout.writeln(result1);
  stdout.writeln(result2);
  // outputs:
  //((((4d20) kh 2) #cf ) #cs ) ===> RollSummary(total: 34, results: [17(d20), 17(d20)], discarded: [12(d20⛔︎), 11(d20⛔︎)])
  //((((4d20) kh 2) #cf ) #cs ) ===> RollSummary(total: 39, results: [20(d20✅), 19(d20)], discarded: [12(d20⛔︎), 1(d20⛔︎)], critSuccessCount: 1)

  // demonstrate navigation of the result graph
  assert(result2.total == 39);
  assert(listEquals(result2.results.map((d) => d.result).toList(), [20, 19]));
  // read the score-related properties
  assert(result2.successCount == 0);
  assert(result2.failureCount == 0);
  assert(result2.critFailureCount == 0);
  assert(result2.critSuccessCount == 1);
  assert(result2.results.where((d) => d.critSuccess).first.result == 20);

  // look at the expression tree :
  // at the top level, it's a 'count' operation that counted the critical success
  final top = result2.detailedResults;
  assert(top.opType == OpType.count);

  // next level is the count critical failures node of the graph
  // NOTE: despite there being a 1 rolled, the criticalFailure expression is _after_ the `1` is discarded by the lower expression
  final critFailureResult = top.left;
  assert(critFailureResult!.opType == OpType.count);
  assert(critFailureResult!.critFailureCount == 0);

  final dropResult = critFailureResult!.left;
  assert(dropResult!.opType == OpType.drop);

  assert(listEquals(result2.discarded.map((d) => d.result).toList(), [12, 1]));

  assert(
    listEquals(dropResult!.discarded.map((d) => d.result).toList(), [12, 1]),
  );

  final rollResult = dropResult!.left;
  assert(rollResult!.opType == OpType.rollDice);

  assert(
    listEquals(rollResult!.results.map((d) => d.result).toList(), [
      20,
      19,
      1,
      12,
    ]),
  );

  final stats = await DiceExpression.create(
    '2d6',
    roller: RNGRoller(Random(1234)),
  ).stats();
  // output:
  //   {mean: 6.99, stddev: 2.4, min: 2, max: 12, count: 1000, histogram: {2: 27, 3: 56, 4: 90, 5: 98, 6: 138, 7: 180, 8: 141, 9: 109, 10: 80, 11: 51, 12: 30}}
  stdout.writeln(stats);
}
