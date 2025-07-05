/// types of die.
enum DieType implements Comparable<DieType> {
  // normal polyhedral (1d6, 1d20, etc)
  polyhedral(),
  // fudge dice
  fudge(hasPotentialValues: true),
  // 1D66 (equivalent to `1d6*10 + 1d6`).
  d66(hasNSides: false),
  // 1d[1,3,5,7,9]
  special(hasPotentialValues: true),
  // single value (e.g. a sum or count of dice)
  singleVal(explodable: false, hasPotentialValues: true);

  const DieType({
    this.explodable = true,
    this.hasPotentialValues = false,
    this.hasNSides = true,
  });

  /// can the die be exploded?
  final bool explodable;

  /// whether the RolledDie must have non-empty potentialValues
  final bool hasPotentialValues;

  /// whether the RolledDie must have non-zero nsides
  final bool hasNSides;

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
}

enum CountType { count, success, failure, critSuccess, critFailure }
