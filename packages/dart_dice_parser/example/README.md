# dart_dice_parser examples

## D20 advantage

```dart
import 'dart:io';
import 'package:dart_dice_parser/dart_dice_parser.dart';


Future<void> main() async {
  final d20adv = DiceExpression.create('2d20 kh');

  final result1 = d20adv.roll();
  stdout.writeln(result1);
}
```
