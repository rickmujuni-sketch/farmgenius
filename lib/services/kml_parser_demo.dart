/// KML Parser Demo - Phase 1
/// Shows how the real farm KML is parsed and automatically categorized
/// Run this to see what zones will be auto-generated

import 'package:flutter/foundation.dart';
import '../models/kml_models.dart';
import 'kml_parser_service.dart';

class KmlParserDemo {
  /// Parse the actual farm KML and print extracted data
  static Future<void> parseAndPrintFarmKml() async {
    try {
      debugPrint('\n========== PHASE 1: KML PARSING ==========\n');

      // Parse the farm KML
      final farm = await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');

      debugPrint('📍 Farm Name: ${farm.farmName}');
      debugPrint('📐 Boundary: ${farm.boundary.name}');
      debugPrint('📏 Area: ${farm.boundary.areaHectares.toStringAsFixed(2)} hectares');
      debugPrint('🧭 Centroid: (${farm.boundary.centroid.latitude.toStringAsFixed(5)}, ${farm.boundary.centroid.longitude.toStringAsFixed(5)})');
      debugPrint('🔢 Boundary Points: ${farm.boundary.coordinates.length}');

      debugPrint('\n--- Extracted Placemarks ---\n');
      debugPrint('Total points: ${farm.placemarks.length}');

      debugPrint('\n📦 BY TYPE:');
      for (final type in farm.placemarksByType.keys) {
        final count = farm.placemarksByType[type]!.length;
        debugPrint('  • ${type.toString().split('.').last}: $count');
      }

      debugPrint('\n🐄 LIVESTOCK DETECTED:');
      if (farm.livestockByType.isEmpty) {
        debugPrint('  (none)');
      } else {
        for (final type in farm.livestockByType.keys) {
          final list = farm.livestockByType[type]!;
          debugPrint('  • ${type.toString().split('.').last}: ${list.length}');
          for (final pm in list) {
            debugPrint('    - ${pm.name} @ (${pm.location.latitude.toStringAsFixed(6)}, ${pm.location.longitude.toStringAsFixed(6)})');
          }
        }
      }

      debugPrint('\n🏢 INFRASTRUCTURE:');
      final infra = farm.infrastructurePlacemarks;
      if (infra.isEmpty) {
        debugPrint('  (none)');
      } else {
        for (final pm in infra) {
          final typeStr = pm.type?.toString().split('.').last ?? 'OTHER';
          debugPrint('  • $typeStr: ${pm.name}');
          debugPrint('    @ (${pm.location.latitude.toStringAsFixed(6)}, ${pm.location.longitude.toStringAsFixed(6)})');
        }
      }

      debugPrint('\n========== END PHASE 1 ==========\n');

      // Print summary for Phase 2
      debugPrint('\n========== PHASE 2 PREVIEW: ZONE GENERATION ==========\n');
      debugPrint('The following ZONE will be generated from this data:\n');

      debugPrint('🌾 CROP ZONES:');
      debugPrint('  • Remaining farm land (${farm.boundary.areaHectares.toStringAsFixed(2)} hectares)');
      debugPrint('  • Could be divided into plots based on water distance');

      debugPrint('\n🐄 LIVESTOCK ZONES:');
      for (final livestockType in farm.livestockByType.keys) {
        final locations = farm.livestockByType[livestockType]!;
        for (final loc in locations) {
          final typeStr = livestockType.toString().split('.').last;
          debugPrint('  • ${loc.name} ($typeStr)');
          debugPrint('    - 100m radius around: (${loc.location.latitude}, ${loc.location.longitude})');
          debugPrint('    - Activities: daily feeding, health checks, breed management');
        }
      }

      debugPrint('\n🏥 INFRASTRUCTURE ZONES:');
      for (final infra in farm.infrastructurePlacemarks) {
        final typeStr = infra.type?.toString().split('.').last ?? 'OTHER';
        debugPrint('  • ${infra.name} ($typeStr)');
        if (typeStr == 'FARMHOUSE') {
          debugPrint('    - Activities: security patrol, maintenance');
        } else if (typeStr == 'WATER_SOURCE') {
          debugPrint('    - Activities: pump maintenance, water testing');
        } else if (typeStr == 'QUARTERS') {
          debugPrint('    - Activities: quarters maintenance, amenity checks');
        }
      }

      debugPrint('\n========== END PHASE 2 PREVIEW ==========\n');
    } catch (e, st) {
      debugPrint('❌ Parse Error: $e');
      debugPrint('$st');
    }
  }

  /// Quick test: verify KML file exists and is valid
  static Future<bool> testKmlFileExists() async {
    try {
      await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');
      debugPrint('✅ KML file parsed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ KML file error: $e');
      return false;
    }
  }
}
