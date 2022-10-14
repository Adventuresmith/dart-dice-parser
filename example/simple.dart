import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

final _log = Logger('main');

void main() {
  Logger.root.level = Level.FINEST;

  Logger.root.onRecord.listen((rec) {
    stdout.writeln(
      '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
    );
  });
  //const diceExpression = "2d6 + 1 + 3d10";

  //print("$diceExpression : ${DiceParser().roll(diceExpression)}");

  const input = '6d6-<';
  final parsed = diceParserFactory.parse(input);

  if (parsed.isSuccess) {
    final roller = parsed.value;
    for (var i = 0; i < 2; i++) {
      final res = roller();
      _log.info("$i : $res = ${res.sum}");
    }
  } else {
    _log.severe(input);
    _log.severe('${' ' * (parsed.position - 1)}^-- ${parsed.message}');
    exit(1);
  }
}
