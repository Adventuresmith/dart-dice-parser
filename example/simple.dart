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

  // create a roller for D20 advantage (roll 2d20, drop lowest)
  final dice = DiceExpression.create('2d20-L', Random.secure());

  // each roll returns different results.
  final int result1 = dice.roll();
  stdout.writeln("Result1: $result1");
  final int result2 = dice.roll();
  stdout.writeln("Result2: $result2");
}
