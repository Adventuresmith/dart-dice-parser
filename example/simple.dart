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
  // By default, dice roller will use Random.secure(). Depending on your use case,
  // it can be much faster to use the pseudorandom generator instead.
  final dice = DiceExpression.create('2d20 kh', Random());

  // each roll returns different results.
  final results1 = dice.roll();
  stdout.writeln("Result1: $results1");
  final results2 = dice.roll();
  stdout.writeln("Result2: $results2");
}
