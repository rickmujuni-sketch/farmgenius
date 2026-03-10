import '../models/breed_recommendation.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';
import 'zone_inference_engine.dart';

class BreedRecommendationService {
  static const Map<String, List<BreedProfile>> _catalog = {
    'cattle': [
      BreedProfile(
        name: 'Jersey',
        species: 'cattle',
        manageability: 92,
        heatTolerance: 82,
        diseaseResistance: 84,
        feedEfficiency: 89,
        fertility: 86,
        temperament: 91,
      ),
      BreedProfile(
        name: 'Ayrshire',
        species: 'cattle',
        manageability: 87,
        heatTolerance: 79,
        diseaseResistance: 82,
        feedEfficiency: 84,
        fertility: 84,
        temperament: 86,
      ),
      BreedProfile(
        name: 'Holstein',
        species: 'cattle',
        manageability: 76,
        heatTolerance: 68,
        diseaseResistance: 72,
        feedEfficiency: 79,
        fertility: 80,
        temperament: 78,
      ),
      BreedProfile(
        name: 'Boran',
        species: 'cattle',
        manageability: 90,
        heatTolerance: 95,
        diseaseResistance: 90,
        feedEfficiency: 84,
        fertility: 83,
        temperament: 86,
      ),
      BreedProfile(
        name: 'Tanzanian Shorthorn',
        species: 'cattle',
        manageability: 89,
        heatTolerance: 93,
        diseaseResistance: 89,
        feedEfficiency: 82,
        fertility: 82,
        temperament: 88,
      ),
      BreedProfile(
        name: 'Sahiwal',
        species: 'cattle',
        manageability: 85,
        heatTolerance: 94,
        diseaseResistance: 88,
        feedEfficiency: 85,
        fertility: 84,
        temperament: 83,
      ),
      BreedProfile(
        name: 'Friesian Cross',
        species: 'cattle',
        manageability: 70,
        heatTolerance: 62,
        diseaseResistance: 64,
        feedEfficiency: 69,
        fertility: 74,
        temperament: 72,
      ),
    ],
    'goats': [
      BreedProfile(
        name: 'Small East African',
        species: 'goats',
        manageability: 93,
        heatTolerance: 96,
        diseaseResistance: 90,
        feedEfficiency: 89,
        fertility: 86,
        temperament: 90,
      ),
      BreedProfile(
        name: 'Galla',
        species: 'goats',
        manageability: 88,
        heatTolerance: 94,
        diseaseResistance: 87,
        feedEfficiency: 85,
        fertility: 84,
        temperament: 86,
      ),
      BreedProfile(
        name: 'Boer Cross',
        species: 'goats',
        manageability: 79,
        heatTolerance: 81,
        diseaseResistance: 76,
        feedEfficiency: 75,
        fertility: 83,
        temperament: 79,
      ),
    ],
    'sheep': [
      BreedProfile(
        name: 'Dorper',
        species: 'sheep',
        manageability: 89,
        heatTolerance: 90,
        diseaseResistance: 85,
        feedEfficiency: 84,
        fertility: 86,
        temperament: 87,
      ),
      BreedProfile(
        name: 'Red Maasai',
        species: 'sheep',
        manageability: 91,
        heatTolerance: 94,
        diseaseResistance: 92,
        feedEfficiency: 86,
        fertility: 84,
        temperament: 88,
      ),
      BreedProfile(
        name: 'Dorper Cross',
        species: 'sheep',
        manageability: 82,
        heatTolerance: 86,
        diseaseResistance: 80,
        feedEfficiency: 78,
        fertility: 82,
        temperament: 83,
      ),
    ],
    'pigs': [
      BreedProfile(
        name: 'Large White Cross',
        species: 'pigs',
        manageability: 80,
        heatTolerance: 74,
        diseaseResistance: 76,
        feedEfficiency: 84,
        fertility: 88,
        temperament: 78,
      ),
      BreedProfile(
        name: 'Landrace Cross',
        species: 'pigs',
        manageability: 76,
        heatTolerance: 71,
        diseaseResistance: 73,
        feedEfficiency: 83,
        fertility: 90,
        temperament: 77,
      ),
    ],
    'chickens': [
      BreedProfile(
        name: 'Kuroiler',
        species: 'chickens',
        manageability: 90,
        heatTolerance: 90,
        diseaseResistance: 86,
        feedEfficiency: 87,
        fertility: 85,
        temperament: 88,
      ),
      BreedProfile(
        name: 'Sasso',
        species: 'chickens',
        manageability: 86,
        heatTolerance: 87,
        diseaseResistance: 82,
        feedEfficiency: 84,
        fertility: 84,
        temperament: 86,
      ),
    ],
  };

  static Future<BreedRecommendationResult?> recommendFromFarm() async {
    try {
      final zones = await ZoneInferenceEngine.inferZonesFromAsset('assets/farm_data/farm_boundary.kml');
      final result = recommendForZones(zones);
      if (result != null) return result;
    } catch (_) {}

    return recommendForZones(GeneratedFarmZones.allZones);
  }

  static Future<List<BreedRecommendationResult>> recommendAllSpeciesFromFarm() async {
    try {
      final zones = await ZoneInferenceEngine.inferZonesFromAsset('assets/farm_data/farm_boundary.kml');
      final results = recommendAllSpeciesForZones(zones);
      if (results.isNotEmpty) return results;
    } catch (_) {}

    return recommendAllSpeciesForZones(GeneratedFarmZones.allZones);
  }

  static List<BreedRecommendationResult> recommendAllSpeciesForZones(List<FarmZone> zones) {
    final livestockZones = zones.where((zone) => zone.type == ZoneType.LIVESTOCK).toList();
    if (livestockZones.isEmpty) return const [];

    final zoneBySpecies = <String, List<FarmZone>>{};
    for (final zone in livestockZones) {
      final species = _normalizeSpecies(zone.metadata['livestock_type']);
      zoneBySpecies.putIfAbsent(species, () => []).add(zone);
    }

    final results = <BreedRecommendationResult>[];
    for (final entry in zoneBySpecies.entries) {
      final result = _recommendForSpeciesZones(entry.key, entry.value);
      if (result != null) {
        results.add(result);
      }
    }

    results.sort((a, b) => b.herdSize.compareTo(a.herdSize));
    return results;
  }

  static BreedRecommendationResult? recommendForZones(List<FarmZone> zones) {
    final livestockZones = zones.where((zone) => zone.type == ZoneType.LIVESTOCK).toList();
    if (livestockZones.isEmpty) return null;

    final speciesCounts = <String, int>{};
    final zoneBySpecies = <String, List<FarmZone>>{};

    for (final zone in livestockZones) {
      final species = _normalizeSpecies(zone.metadata['livestock_type']);
      final headCount = int.tryParse(zone.metadata['head_count'] ?? '') ?? 0;
      speciesCounts[species] = (speciesCounts[species] ?? 0) + (headCount == 0 ? 1 : headCount);
      zoneBySpecies.putIfAbsent(species, () => []).add(zone);
    }

    final dominantSpecies = speciesCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _recommendForSpeciesZones(dominantSpecies, zoneBySpecies[dominantSpecies] ?? []);
  }

  static BreedRecommendationResult? _recommendForSpeciesZones(
    String species,
    List<FarmZone> speciesZones,
  ) {
    final candidates = _catalog[species];
    if (candidates == null || candidates.isEmpty || speciesZones.isEmpty) return null;

    var herdSize = 0;
    for (final zone in speciesZones) {
      final headCount = int.tryParse(zone.metadata['head_count'] ?? '') ?? 0;
      herdSize += headCount == 0 ? 1 : headCount;
    }

    final currentBreed = _extractCurrentBreed(speciesZones);
    final observedBreeds = _extractObservedBreeds(speciesZones);
    final stockUpdateDate = _extractLatestStockUpdateDate(speciesZones);
    final stockUpdateNote = _extractStockUpdateNote(speciesZones);

    final grazingReady = _activityCoverage(speciesZones, ActivityStage.GRAZING);
    final healthDiscipline = _activityCoverage(speciesZones, ActivityStage.HEALTH_CHECK);
    final breedingDiscipline = _activityCoverage(speciesZones, ActivityStage.BREEDING);

    final ranked = candidates
        .map((profile) {
          final score = _scoreBreed(
            profile: profile,
            herdSize: herdSize,
            grazingReady: grazingReady,
            healthDiscipline: healthDiscipline,
            breedingDiscipline: breedingDiscipline,
            observedBreeds: observedBreeds,
          );

          return BreedRecommendation(
            breed: profile,
            score: score,
            reasons: _buildReasons(
              profile: profile,
              herdSize: herdSize,
              healthDiscipline: healthDiscipline,
              grazingReady: grazingReady,
            ),
          );
        })
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return BreedRecommendationResult(
      species: species,
      currentBreed: currentBreed,
      herdSize: herdSize,
      stockUpdateDate: stockUpdateDate,
      stockUpdateNote: stockUpdateNote,
      ranked: ranked,
      maintenancePlan: _maintenancePlan(
        top: ranked.first.breed,
        species: species,
        currentBreed: currentBreed,
        herdSize: herdSize,
        healthDiscipline: healthDiscipline,
      ),
    );
  }

  static double _scoreBreed({
    required BreedProfile profile,
    required int herdSize,
    required double grazingReady,
    required double healthDiscipline,
    required double breedingDiscipline,
    required Set<String> observedBreeds,
  }) {
    final healthWeight = healthDiscipline < 0.7 ? 0.22 : 0.18;
    final feedWeight = grazingReady < 0.5 ? 0.18 : 0.14;

    var score =
        profile.manageability * 0.35 +
        profile.heatTolerance * 0.20 +
        profile.diseaseResistance * healthWeight +
        profile.feedEfficiency * feedWeight +
        profile.fertility * 0.08 +
        profile.temperament * 0.05;

    if (herdSize >= 30) score += profile.temperament * 0.04;
    if (breedingDiscipline < 0.5 && profile.fertility < 75) score -= 3;
    if (observedBreeds.contains(profile.name.toLowerCase())) score += 4;

    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  static List<String> _buildReasons({
    required BreedProfile profile,
    required int herdSize,
    required double healthDiscipline,
    required double grazingReady,
  }) {
    final reasons = <String>[
      'Manageability ${profile.manageability}/100 and temperament ${profile.temperament}/100 fit daily handling needs.',
      'Heat tolerance ${profile.heatTolerance}/100 and disease resistance ${profile.diseaseResistance}/100 fit local climate risk.',
    ];

    if (herdSize >= 30) {
      reasons.add('Large herd context ($herdSize head) favors calmer, easy-supervision breeds.');
    }
    if (healthDiscipline < 0.7) {
      reasons.add('Health-check gaps increase value of stronger natural disease resistance.');
    }
    if (grazingReady < 0.5) {
      reasons.add('Lower grazing readiness increases importance of feed efficiency.');
    }

    return reasons;
  }

  static List<String> _maintenancePlan({
    required BreedProfile top,
    required String species,
    required String? currentBreed,
    required int herdSize,
    required double healthDiscipline,
  }) {
    final plan = <String>[
      'Create a focused breeding nucleus for ${top.name} ($species) and keep replacement records by mother line.',
      'Track service dates, birth outcomes, and culling reasons monthly to prevent unmanaged inbreeding.',
      'Run weight/body-condition checks every 30 days and separate low-performers for targeted feed.',
      'Schedule vaccination and parasite control quarterly with batch logs (drug, dose, date, handler).',
      healthDiscipline < 0.7
          ? 'Enforce a fixed weekly health inspection routine until completion consistency improves.'
          : 'Maintain current health-check cadence and audit compliance at least monthly.',
      'Keep one simple scorecard: growth rate, survival, treatment cost, and temperament incidents per batch.',
    ];

    final gestation = _gestationGuidance(
      species: species,
      currentBreed: currentBreed,
      herdSize: herdSize,
    );
    if (gestation != null) {
      plan.add(gestation);
    }

    plan.add(
      'Align planting and fodder scheduling with projected birth windows so lactation and young-stock nutrition are covered without feed gaps.',
    );

    return plan;
  }

  static String? _gestationGuidance({
    required String species,
    required String? currentBreed,
    required int herdSize,
  }) {
    if (species == 'goats') {
      return 'Goat gestation planning target: 145-155 days (about 5 months / 21 weeks).';
    }

    if (species == 'cattle') {
      final breedText = (currentBreed ?? '').toLowerCase();
      final hasBrahman = breedText.contains('brahman');
      if (hasBrahman) {
        return 'Cattle gestation planning target: ~283 days (normal 279-287), with Brahman-type lines often averaging closer to ~292 days.';
      }
      return 'Cattle gestation planning target: ~283 days (normal 279-287); breed, calf sex, and nutrition can shift timing toward ~280 or higher.';
    }

    if (species == 'sheep') {
      final breedText = (currentBreed ?? '').toLowerCase();
      if (breedText.contains('dorper') && herdSize > 0) {
        return 'Dorper gestation planning target for your flock ($herdSize head): typically ~147 days, with a normal range of 143-151 days.';
      }
      return 'Sheep gestation planning target: typically ~147 days, with a normal range of 143-151 days.';
    }

    return null;
  }

  static double _activityCoverage(List<FarmZone> zones, ActivityStage stage) {
    if (zones.isEmpty) return 0;
    final withStage = zones.where((zone) => zone.hasActivity(stage)).length;
    return withStage / zones.length;
  }

  static String? _extractCurrentBreed(List<FarmZone> zones) {
    for (final zone in zones) {
      final breed = zone.metadata['breed'];
      if (breed != null && breed.trim().isNotEmpty) return breed.trim();
    }
    return null;
  }

  static Set<String> _extractObservedBreeds(List<FarmZone> zones) {
    final observed = <String>{};

    for (final zone in zones) {
      final breed = zone.metadata['breed'];
      if (breed != null && breed.trim().isNotEmpty) {
        observed.addAll(_splitBreedList(breed));
      }

      final breedMix = zone.metadata['breed_mix'];
      if (breedMix != null && breedMix.trim().isNotEmpty) {
        observed.addAll(_splitBreedList(breedMix));
      }
    }

    return observed;
  }

  static Set<String> _splitBreedList(String value) {
    return value
        .split(RegExp(r'[,;|]'))
        .map((item) => item.split(':').first.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static DateTime? _extractLatestStockUpdateDate(List<FarmZone> zones) {
    DateTime? latest;

    for (final zone in zones) {
      final raw = zone.metadata['stock_update_date'];
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }

    return latest;
  }

  static String? _extractStockUpdateNote(List<FarmZone> zones) {
    for (final zone in zones) {
      final note = zone.metadata['stock_update_note'];
      if (note != null && note.trim().isNotEmpty) {
        return note.trim();
      }
    }
    return null;
  }

  static String _normalizeSpecies(String? raw) {
    final value = (raw ?? '').toLowerCase().trim();
    if (value.contains('cattle') || value.contains('cow') || value.contains('bovine')) return 'cattle';
    if (value.contains('goat')) return 'goats';
    if (value.contains('sheep')) return 'sheep';
    if (value.contains('pig')) return 'pigs';
    if (value.contains('chicken') || value.contains('poultry') || value.contains('guinea')) return 'chickens';
    return 'cattle';
  }
}
