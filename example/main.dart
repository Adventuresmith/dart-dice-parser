import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:logging/logging.dart';

final Logger log = Logger('main');

void main(List<String> arguments) async {
  Logger.root.level = Level.FINE;

  Logger.root.onRecord.listen((rec) {
    print("$rec");
    /*
    if (rec.level == Level.INFO) {
      print('${rec.message}');
    } else if (rec.level > Level.INFO) {
      print("${rec.level}: ${rec.message}");
    }
    developer.log(rec.message,
        time: rec.time,
        sequenceNumber: rec.sequenceNumber,
        level: rec.level.value,
        name: rec.loggerName,
        zone: rec.zone,
        error: rec.object,
        stackTrace: rec.stackTrace);
        */
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
          Logger.root.level = Level.WARNING;
        }
      },
    )
    ..addFlag(
      "stats",
      abbr: "s",
      help: "output dice stats. assumes n=10000 unless overridden",
    )
    ..addFlag("help", abbr: "h");

  final results = argParser.parse(arguments);
  if (results["help"] as bool) {
    print("Usage:");
    print(argParser.usage);
    exit(1);
  }
  exit(
    await run(
      numRolls: int.parse(results["num"] as String),
      expression: results.rest.join(" "),
      stats: results["stats"] as bool,
    ),
  );
}

Future<int> run({
  required int numRolls,
  required String expression,
  required bool stats,
}) async {
  if (expression.isEmpty) {
    print("Supply a dice expression. e.g. '2d6+1'");
    return 1;
  }
  final diceParser = DiceParser();

  if (stats) {
    final n = numRolls == 1 ? 10000 : numRolls;
    final stats = await diceParser.stats(diceStr: expression, numRolls: n);
    print(stats);
  } else {
    var i = 0;
    await for (final r in diceParser.rollN(expression, numRolls)) {
      i++;
      print("$i: $r");
    }
  }
  return 0;
}
