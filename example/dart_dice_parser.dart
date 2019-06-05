import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';

main(List<String> arguments) {
  var argParser = new ArgParser()
    ..addOption(
      "num",
      abbr: "n",
      help: "number of times to roll the expression",
      defaultsTo: "1",
    );

  var results = argParser.parse(arguments);

  exit(roll(int.parse(results["num"]), results.rest.join(" ")));
}

int roll(int numRolls, String expression) {
  if (expression.isEmpty) {
    print("Supply a dice expression. e.g. '2d6+1'");
    return 1;
  }
  print("Evaluating: $expression\n");
  var diceParser = new DiceParser();

  // use the parser, rather than the evaluator -- this makes grouping easier to debug
  print("\t\t [${diceParser.parse(expression)}]\n");

  diceParser
      .rollN(expression, numRolls)
      .asMap() // convert list to map so have an index
      .forEach((i, r) => print("${i + 1}: $r"));

  return 0;
}
