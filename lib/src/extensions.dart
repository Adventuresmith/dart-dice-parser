import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'rolled_die.dart';

extension RolledDieIListExtensions on IList<RolledDie> {
  int get sum => map((d) => d.result).fold(0, (sum, i) => sum + i);

  int get successCount => where((d) => d.success).length;

  int get failureCount => where((d) => d.failure).length;

  int get critSuccessCount => where((d) => d.critSuccess).length;

  int get critFailureCount => where((d) => d.critFailure).length;
}
