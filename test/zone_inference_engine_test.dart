import 'package:flutter_test/flutter_test.dart';
import 'package:farmgenius/models/farm_zone.dart';
import 'package:farmgenius/services/kml_parser_service.dart';
import 'package:farmgenius/services/zone_inference_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZoneInferenceEngine', () {
    test('creates livestock zones with expected calendars and crop zone from remaining land', () async {
      final farm = await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');
      final zones = ZoneInferenceEngine.inferZones(farm);

      final livestockZones = zones.where((z) => z.type == ZoneType.LIVESTOCK).toList();
      final cropZones = zones.where((z) => z.type == ZoneType.CROP).toList();

      expect(livestockZones.length, 4);
      expect(cropZones.length, 1);

      for (final zone in livestockZones) {
        expect(zone.metadata['livestock_type'], isNotNull);
        expect(zone.metadata['radius_meters'], isNotNull);
        expect(zone.metadata['expected_calendar'], isNotEmpty);
        expect(zone.boundary.length, greaterThan(8));
      }

      final crop = cropZones.first;
      expect(crop.metadata['inference_mode'], 'remaining_land');
      expect(crop.metadata['expected_calendar'], isNotEmpty);
      expect(crop.areaHectares, greaterThan(0));
    });
  });
}
