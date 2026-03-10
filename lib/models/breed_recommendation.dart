class BreedProfile {
  final String name;
  final String species;
  final int manageability;
  final int heatTolerance;
  final int diseaseResistance;
  final int feedEfficiency;
  final int fertility;
  final int temperament;

  const BreedProfile({
    required this.name,
    required this.species,
    required this.manageability,
    required this.heatTolerance,
    required this.diseaseResistance,
    required this.feedEfficiency,
    required this.fertility,
    required this.temperament,
  });
}

class BreedRecommendation {
  final BreedProfile breed;
  final double score;
  final List<String> reasons;

  const BreedRecommendation({
    required this.breed,
    required this.score,
    required this.reasons,
  });
}

class BreedRecommendationResult {
  final String species;
  final String? currentBreed;
  final int herdSize;
  final DateTime? stockUpdateDate;
  final String? stockUpdateNote;
  final List<BreedRecommendation> ranked;
  final List<String> maintenancePlan;

  const BreedRecommendationResult({
    required this.species,
    required this.currentBreed,
    required this.herdSize,
    required this.stockUpdateDate,
    required this.stockUpdateNote,
    required this.ranked,
    required this.maintenancePlan,
  });

  BreedRecommendation get topRecommendation => ranked.first;
}
