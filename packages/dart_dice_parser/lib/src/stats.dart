import 'dart:collection';
import 'dart:math';

/// Uses Welford's algorithm to compute variance for stddev along
/// with other stats.
///
// long n = 0;
// double mu = 0.0;
// double sq = 0.0;
//
// void update(double x) {
//     ++n;
//     double muNew = mu + (x - mu)/n;
//     sq += (x - mu) * (x - muNew)
//     mu = muNew;
// }
// double mean() { return mu; }
// double var() { return n > 1 ? sq/n : 0.0; }
class StatsCollector {
  int _minVal = 0;
  int _maxVal = 0;
  int _count = 0;
  bool _initialized = false;
  double _mean = 0.0;
  double _sq = 0.0;

  final _histogram = SplayTreeMap<int, int>();

  /// update current stats w/ new value
  void update(int val) {
    _count++;
    if (!_initialized) {
      _minVal = _maxVal = val;
      _initialized = true;
    } else {
      _minVal = min(_minVal, val);
      _maxVal = max(_maxVal, val);
    }

    _histogram[val] = (_histogram[val] ?? 0) + 1;

    final meanNew = _mean + (val - _mean) / _count;
    _sq += (val - _mean) * (val - meanNew);
    _mean = meanNew;
  }

  num get _variance => _count > 1 ? _sq / _count : 0.0;

  num get _stddev => sqrt(_variance);

  /// retrieve stats as map
  Map<String, dynamic> toJson({int precision = 3}) => {
    'mean': double.parse(_mean.toStringAsPrecision(precision)),
    'stddev': double.parse(_stddev.toStringAsPrecision(precision)),
    'min': _minVal,
    'max': _maxVal,
    'count': _count,
    'histogram': _histogram,
  };
}
