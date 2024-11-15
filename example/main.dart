import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dart_dice_parser/dart_dice_parser.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';

const defaultStatsNum = 10000;

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
  var random = Random.secure();

  DiceExpression.registerListener((rollResult) {
    //stdout.writeln('${rollResult.opType.name} -> $rollResult');
  });

  final argParser = ArgParser()
    ..addOption(
      'num',
      abbr: 'n',
      help: 'Number of times to roll the expression',
      defaultsTo: '1',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'plain',
      help: 'output type',
      allowedHelp: {
        'plain': 'output using toString',
        'json': 'output JSON',
        'pretty':
            'output result summary and detailed results of evaluating the expression tree',
      },
    )
    ..addOption(
      'random',
      abbr: 'r',
      defaultsTo: 'pseudo',
      help: 'Random number generator to use.',
      allowedHelp: {
        'secure': 'secure random',
        'pseudo': 'pseudorandom generator',
        '<integer>': 'pseudorandom generator initialized with given seed',
      },
      callback: (val) {
        switch (val?.toLowerCase()) {
          case 'pseudo':
            random = Random();
          case 'secure':
            random = Random.secure();
          default:
            try {
              random = Random(int.parse(val!));
            } on FormatException {
              stderr.writeln("Invalid random number generator '$val'.");
              exit(ExitCode.usage.code);
            }
        }
      },
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging',
      callback: (verbose) {
        if (verbose) {
          Logger.root.level = Level.FINEST;
        } else {
          Logger.root.level = Level.INFO;
        }
      },
    )
    ..addFlag(
      'stats',
      abbr: 's',
      help:
          'Output statistics for the given dice expression. Uses n=$defaultStatsNum unless overridden',
    )
    ..addFlag('help', abbr: 'h');

  final results = argParser.parse(arguments);
  if (results['help'] as bool) {
    stderr.writeln('Usage:');
    stderr.writeln(argParser.usage);
    exit(ExitCode.usage.code);
  }

  final input = results.rest.join(' ');
  if (input.isEmpty) {
    stderr.writeln("Supply a dice expression. e.g. '2d6+1'");
    exit(ExitCode.noInput.code);
  }

  try {
    final collectStats = results['stats'] as bool;
    if (collectStats) {
      random = Random();
    }
    final diceExpr = DiceExpression.create(input, random);

    exit(
      await run(
        expression: diceExpr,
        numRolls: int.parse(results['num'] as String),
        stats: collectStats,
        output: results['output'] as String,
      ),
    );
  } on FormatException catch (e) {
    stderr.writeln(e.toString());
    exit(ExitCode.noInput.code);
  }
}

Future<int> run({
  required int numRolls,
  required DiceExpression expression,
  required bool stats,
  required String output,
}) async {
  if (stats) {
    final stats =
        await expression.stats(num: numRolls == 1 ? defaultStatsNum : numRolls);
    stdout.writeln(stats);
  } else {
    await for (final r in expression.rollN(numRolls)) {
      if (output == 'json') {
        stdout.writeln(json.encode(r));
      } else if (output == 'pretty') {
        stdout.writeln(r.toStringPretty());
      } else {
        stdout.writeln(r.toString());
      }
    }
  }
  return ExitCode.success.code;
}
