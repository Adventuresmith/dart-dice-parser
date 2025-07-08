# dart_dice_parser examples

## D20 advantage

```dart
import 'dart:io';
import 'package:dart_dice_parser/dart_dice_parser.dart';


Future<void> main() async {
  // roll 2 d20s, keep the highest.
  // score the results: 
  //  cf == a 1 is a critical failure
  //  cs == a 20 is a critical success
  final d20adv = DiceExpression.create('2d20 kh #cs #cf');

  final result1 = await d20adv.roll();
  stdout.writeln(result1);
}
```
