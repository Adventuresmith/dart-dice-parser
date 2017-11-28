import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:args/args.dart';

import 'dart:io';

main(List<String> arguments) {

  var argParser = new ArgParser()
      ..addOption("num", abbr: "n", help: "number of times to roll the expression", defaultsTo: "1", );
  
  var results = argParser.parse(arguments);

  exit(
    roll(int.parse(results["num"]), results.rest.join(" "))
  );
}

int roll(int numRolls, String expression) {
  if (expression.isEmpty) {
    print ("Supply a dice expression. e.g. '2d6+1'");
    return 1;
  }
  print ("Evaluating: $expression\n");
  var diceParser = new DiceParser();
  for (int i=0; i < numRolls; i++) {
    print("${i+1}: ${diceParser.roll(expression)}\n");
  }
  return 0;
}
