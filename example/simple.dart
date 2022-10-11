import 'package:dart_dice_parser/dart_dice_parser.dart';

void main() {
  var diceExpression = "2d6 + 1 + 3d10";

  print("$diceExpression : ${DiceParser().roll(diceExpression)}");
}
