import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.FINEST;

  Logger.root.onRecord.listen((rec) {
    print("$rec");
  });
  //const diceExpression = "2d6 + 1 + 3d10";

  //print("$diceExpression : ${DiceParser().roll(diceExpression)}");

  const input = '4d6-H';
  final parsed = diceParserFactory.parse(input);

  if (parsed.isSuccess) {
    final roller = parsed.value;
    for (var i = 0; i < 2; i++) {
      final res = roller();
      Logger('main').info("$i : $res = ${res.sum}");
    }
  } else {
    Logger('main').severe(input);
    Logger('main')
        .severe('${' ' * (parsed.position - 1)}^-- ${parsed.message}');
    exit(1);
  }
}
