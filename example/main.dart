import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {
  Logger.root.level = Level.INFO;

  Logger.root.onRecord.listen((rec) {
    if (rec.level > Level.INFO) {
      stderr.writeln(
        '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
      );
    } else {
      stdout.writeln(
        '[${rec.level.name.padLeft(7)}] ${rec.loggerName.padLeft(12)}: ${rec.message}',
      );
    }
  });

  final argParser = ArgParser()
    ..addOption(
      "num",
      abbr: "n",
      help: "number of times to roll the expression",
      defaultsTo: "1",
    )
    ..addFlag(
      "verbose",
      abbr: "v",
      help: "enable verbose logging",
      callback: (verbose) {
        if (verbose) {
          Logger.root.level = Level.FINEST;
        } else {
          Logger.root.level = Level.INFO;
        }
      },
    )
    ..addFlag(
      "stats",
      abbr: "s",
      help: "output dice stats. assumes n=500 unless overridden",
    )
    ..addFlag("help", abbr: "h");

  final results = argParser.parse(arguments);
  if (results["help"] as bool) {
    stderr.writeln("Usage:");
    stderr.writeln(argParser.usage);
    exit(1);
  }

  final input = results.rest.join(" ");
  if (input.isEmpty) {
    stderr.writeln("Supply a dice expression. e.g. '2d6+1'");
    exit(1);
  }

  final diceExpr = DiceExpression.create(input);

  exit(
    await run(
      expression: diceExpr,
      numRolls: int.parse(results["num"] as String),
      stats: results["stats"] as bool,
    ),
  );
}

Future<int> run({
  required int numRolls,
  required DiceExpression expression,
  required bool stats,
}) async {
  if (stats) {
    final stats = await expression.stats(num: numRolls == 1 ? 500 : numRolls);
    stdout.writeln(stats);
  } else {
    var i = 0;
    await for (final r in expression.rollN(numRolls)) {
      i++;
      stdout.writeln("$r");
    }
  }
  return 0;
}
