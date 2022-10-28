import 'dart:io';
import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.FINEST;

  Logger.root.onRecord.listen((rec) {
    stdout.writeln(
      '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
    );
  });

  // Create a roller for D20 advantage (roll 2d20, keep highest).
  //
  // By default, dice roller will use Random.secure(). Depending on your use case,
  // it can be much faster to use the pseudorandom generator instead.
  final d20adv = DiceExpression.create('2d20 kh', Random());

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 15, results: [15] , metadata: {dropped: [8], rolled: [8, 15]})

  stdout.writeln(d20adv.roll());
  // outputs:
  //   ((2d20)kh) => RollResult(total: 20, results: [20] , metadata: {dropped: [5], rolled: [5, 20]})
}
