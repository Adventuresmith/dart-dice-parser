import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

final Logger log = Logger('main');

void main(List<String> arguments) {
  Logger.root.level = Level.INFO;

  Logger.root.onRecord.listen((rec) {
    print('$rec');
  });

  var argParser = ArgParser()
    ..addOption(
      "num",
      abbr: "n",
      help: "number of times to roll the expression",
      defaultsTo: "1",
    )
    ..addFlag("verbose",
        abbr: "v",
        help: "enable verbose logging",
        defaultsTo: false, callback: (verbose) {
      if (verbose) {
        Logger.root.level = Level.ALL;
      } else {
        Logger.root.level = Level.INFO;
      }
    })
    ..addFlag("stats",
        abbr: "s",
        help: "output dice stats. assumes n=1000 unless overridden",
        defaultsTo: false)
    ..addFlag("help", abbr: "h", defaultsTo: false);

  var results = argParser.parse(arguments);
  if (results["help"]) {
    print("Usage:");
    print(argParser.usage);
    exit(1);
  }
  exit(run(
      numRolls: int.parse(results["num"]),
      expression: results.rest.join(" "),
      stats: results["stats"]));
}

int run({int numRolls, String expression, bool stats}) {
  if (expression.isEmpty) {
    print("Supply a dice expression. e.g. '2d6+1'");
    return 1;
  }
  var diceParser = DiceParser();

  // use the parser here because we'll display $result on success,
  // and it's helpful sometimes
  var result = diceParser.parse(expression);
  if (result.isFailure) {
    print("""
Parsing failure:
    $expression
    ${' ' * (result.position - 1)}^-- ${result.message}
    """);
    return 1;
  }

  // use the parser to display parse results/grouping
  log.fine("Evaluating: $expression => $result\n");

  if (stats) {
    var n = numRolls == 1 ? 1000 : numRolls;
    var stats = diceParser.stats(diceStr: expression, numRolls: n);
    print(stats);
  } else {
    // but use the evaluator via roll/rollN to actually parse and perform dice roll
    diceParser
        .rollN(expression, numRolls)
        .asMap() // convert list to map so have an index
        .forEach((i, r) => print("${i + 1}, $r"));
  }
  return 0;
}
