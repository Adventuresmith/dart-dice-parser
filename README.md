# dart_dice_parser

A library for parsing dice notation


## Usage

A simple usage example:

    import 'package:dart_dice_parser/dart_dice_parser.dart';

    main() {

      var diceParser = new DiceParser();

      var diceExpression = "2d6 + 1 + 3d10";

      print("$diceExpression : ${diceParser.roll(diceExpression)}");
    }

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/stevesea/dart-dice-parser/issues


# TODO

decide if want to continue w/ this library , or use D20 :  https://pub.dev/packages/d20