import 'package:logging/logging.dart';

mixin LoggingMixin {
  Logger? _logger;
  Logger get log {
    return _logger ??= Logger(runtimeType.toString());
  }
}
