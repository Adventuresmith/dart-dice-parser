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

  final roller = diceParserFactory.parse('10d!6').value;

  for (var i = 0; i < 2; i++) {
    final res = roller();
    Logger('main').info("$i : $res = ${res.sum}");
  }
}
