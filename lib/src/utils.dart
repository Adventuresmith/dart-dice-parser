import 'package:logging/logging.dart';

mixin LoggingMixin {
  Logger? _logger;

  Logger get logger => _logger ??= Logger(runtimeType.toString());
}
