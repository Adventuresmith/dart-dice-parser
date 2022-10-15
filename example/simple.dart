import 'dart:io';

import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.FINEST;

  Logger.root.onRecord.listen((rec) {
    stdout.writeln(
      '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
    );
  });

  const input = '2d20-L';
  final diceExpr = DiceExpressionFactory().create(input);

  for (var i = 0; i < 2; i++) {
    final int result = diceExpr.roll();
    stdout.writeln("$i : $result");
  }
}
