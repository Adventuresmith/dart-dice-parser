# dart_dice_parser
[![Pub Package](https://img.shields.io/pub/v/dart_dice_parser.svg)](https://pub.dartlang.org/packages/dart_dice_parser)

A library for parsing dice notation


## Usage

A simple usage example:

```dart
    import 'package:dart_dice_parser/dart_dice_parser.dart';

    main() {
      var diceExpression = "2d6 + 1 + 3d10";

      print("$diceExpression : ${roll(diceExpression)}");
    }

    int roll(String diceStr) {
        var result = DiceParser().evaluate(diceStr);

        if (result.isFailure) {
            print("Failure:");
            print('\t${expression}');
            print('\t${' ' * (result.position - 1)}^-- ${result.message}');
            return 1;
        } else {
            return result.value;
        }
    }
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues
