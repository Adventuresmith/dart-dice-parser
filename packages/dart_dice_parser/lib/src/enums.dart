/// types of die.
enum DieType implements Comparable<DieType> {
  // normal polyhedral (1d6, 1d20, etc)
  polyhedral(),
  // fudge dice
  fudge(requirePotentialValues: true),
  // 1D66 (equivalent to `1d6*10 + 1d6`).
  d66(requireNSides: false),
  // 1d[1,3,5,7,9]
  nvals(requirePotentialValues: true),
  // single value (e.g. a sum or count of dice)
  singleVal(explodable: false, requirePotentialValues: true);

  const DieType({
    this.explodable = true,
    this.requirePotentialValues = false,
    this.requireNSides = true,
  });

  /// can the die be exploded?
  final bool explodable;

  /// whether the RolledDie must have non-empty potentialValues
  final bool requirePotentialValues;

  /// whether the RolledDie must have non-zero nsides
  final bool requireNSides;

  @override
  int compareTo(DieType dieType) => index.compareTo(dieType.index);
}

enum OpType {
  value, // leaf nodes which are simple integer values
  add,
  subtract,
  multiply,
  count,
  drop,
  clamp,
  rollDice,
  rollFudge,
  rollPercent,
  rollD66,
  rollVals,
  rollPenetration,
  reroll,
  compound,
  explode,
  sort,
  comma,
  total,
}

enum CountType { count, success, failure, critSuccess, critFailure }
