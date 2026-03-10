import 'package:farmgenius/models/farm_zone.dart';
import 'package:farmgenius/services/breed_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BreedRecommendationService', () {
    test('returns ranked recommendation for livestock zones', () {
      final zones = [
        const FarmZone(
          id: 'l1',
          name: 'Livestock A',
          description: 'Cattle block',
          type: ZoneType.LIVESTOCK,
          areaHectares: 8,
          boundary: [GeoPoint(lat: 0, lng: 0)],
          metadata: {
            'livestock_type': 'Cattle',
            'head_count': '40',
            'breed': 'Tanzanian Shorthorn',
            'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING,CALVING',
          },
        ),
      ];

      final result = BreedRecommendationService.recommendForZones(zones);

      expect(result, isNotNull);
      expect(result!.species, 'cattle');
      expect(result.ranked, isNotEmpty);
      expect(result.topRecommendation.score, greaterThan(0));
      expect(result.maintenancePlan.length, greaterThanOrEqualTo(5));
    });

    test('returns null when no livestock zones are available', () {
      final zones = [
        const FarmZone(
          id: 'c1',
          name: 'Crop Zone',
          description: 'Maize',
          type: ZoneType.CROP,
          areaHectares: 5,
          boundary: [GeoPoint(lat: 0, lng: 0)],
          metadata: {
            'zone_type': 'crop',
            'expected_calendar': 'PLANTING,GROWTH,HARVEST',
          },
        ),
      ];

      final result = BreedRecommendationService.recommendForZones(zones);

      expect(result, isNull);
    });

    test('recognizes Feb 16 2026 introduced breeds in ranking', () {
      final zones = [
        const FarmZone(
          id: 'l1',
          name: 'Cattle Block',
          description: 'Updated cattle stock',
          type: ZoneType.LIVESTOCK,
          areaHectares: 8,
          boundary: [GeoPoint(lat: 0, lng: 0)],
          metadata: {
            'livestock_type': 'Cattle',
            'head_count': '30',
            'breed': 'Jersey, Ayrshire, Holstein',
            'breed_mix': 'Jersey:10,Ayrshire:10,Holstein:10',
            'stock_update_date': '2026-02-16',
            'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING,CALVING',
          },
        ),
        const FarmZone(
          id: 'l2',
          name: 'Sheep Block',
          description: 'Dorper stock',
          type: ZoneType.LIVESTOCK,
          areaHectares: 2,
          boundary: [GeoPoint(lat: 0, lng: 0)],
          metadata: {
            'livestock_type': 'Sheep',
            'head_count': '10',
            'breed': 'Dorper',
            'stock_update_date': '2026-02-16',
            'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING',
          },
        ),
      ];

      final result = BreedRecommendationService.recommendForZones(zones);

      expect(result, isNotNull);
      expect(result!.species, 'cattle');
      expect(result.currentBreed, contains('Jersey'));

      final candidateNames = result.ranked.map((item) => item.breed.name).toList();
      expect(candidateNames, contains('Jersey'));
      expect(candidateNames, contains('Ayrshire'));
      expect(candidateNames, contains('Holstein'));
    });

    test('adds Dorper gestation and fodder/plant alignment guidance', () {
      final zones = [
        const FarmZone(
          id: 's1',
          name: 'Dorper Pen',
          description: 'Sheep breeding unit',
          type: ZoneType.LIVESTOCK,
          areaHectares: 2,
          boundary: [GeoPoint(lat: 0, lng: 0)],
          metadata: {
            'livestock_type': 'Sheep',
            'head_count': '10',
            'breed': 'Dorper',
            'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING',
          },
        ),
      ];

      final result = BreedRecommendationService.recommendForZones(zones);

      expect(result, isNotNull);
      expect(result!.species, 'sheep');
      expect(
        result.maintenancePlan.any((line) => line.contains('147') && line.contains('143-151')),
        isTrue,
      );
      expect(
        result.maintenancePlan.any((line) => line.toLowerCase().contains('planting') && line.toLowerCase().contains('fodder')),
        isTrue,
      );
    });
  });
}
