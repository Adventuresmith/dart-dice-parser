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
  var diceParser = new DiceParser();

  var result = diceParser.parse(expression);
  if (result.isFailure) {
    print("Failure:");
    print('\t' + expression);
    print('\t${' ' * (result.position - 1)}^-- ${result.message}');
    return 1;
  }
  // use the parser to display parse results
  print("Evaluating: $expression => ${result}\n");
  // but use the evaluator via roll/rollN to actually parse and perform dice roll
  diceParser
      .rollN(expression, numRolls)
      .asMap() // convert list to map so have an index
      .forEach((i, r) => print("${i + 1}: $r"));

  return 0;
}
