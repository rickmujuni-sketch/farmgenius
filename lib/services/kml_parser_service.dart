/// KML Parser Service
/// Phase 1: Parse real farm KML files to extract boundaries and placemarks
/// Uses xml.dart to parse XML/KML format
library;

import 'package:xml/xml.dart' as xml;
import 'package:flutter/services.dart';
import '../models/kml_models.dart';

class KmlParser {
  /// Parse KML from file path (asset)
  static Future<ParsedKmlFarm> parseFromAsset(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    return parseFromString(content);
  }

  /// Parse KML from raw XML string
  static ParsedKmlFarm parseFromString(String kmlContent) {
    final document = xml.XmlDocument.parse(kmlContent);
    return _parseDocument(document);
  }

  /// Internal: Parse XML document structure
  static ParsedKmlFarm _parseDocument(xml.XmlDocument document) {
    // Extract farm name from Document name
    String farmName = 'Farm';
    final documentElement = document.findAllElements('Document').firstOrNull;
    final nameElem = documentElement?.findElements('name').firstOrNull ??
        document.findAllElements('name').firstOrNull;
    if (nameElem != null) {
      farmName = nameElem.innerText;
    }

    // Extract Placemarks (polygons and points)
    final placemarks = <KmlPlacemark>[];
    FarmBoundary? farmBoundary;

    for (final placemark in document.findAllElements('Placemark')) {
      final pmId = placemark.getAttribute('id') ?? 'unknown';
      final pmNameElem = placemark.findElements('name').firstOrNull;
      final pmName = pmNameElem?.innerText ?? 'Unnamed';

      // Check if it's a Polygon (farm boundary)
      final polygon = placemark.findAllElements('Polygon').firstOrNull;
      if (polygon != null) {
        farmBoundary = _parsePolygon(pmId, pmName, polygon);
        continue;
      }

      // Check if it's a Point (infrastructure/livestock)
      final point = placemark.findAllElements('Point').firstOrNull;
      if (point != null) {
        final pm = _parsePoint(pmId, pmName, placemark, point);
        placemarks.add(pm);
      }
    }

    if (farmBoundary == null) {
      throw Exception('No farm boundary polygon found in KML');
    }

    return ParsedKmlFarm(
      farmName: farmName,
      boundary: farmBoundary,
      placemarks: placemarks,
    );
  }

  /// Parse Polygon element to FarmBoundary
  static FarmBoundary _parsePolygon(
    String id,
    String name,
    xml.XmlElement polygonElem,
  ) {
    final coordinates = <GeoCoordinate>[];

    // Find outerBoundaryIs -> LinearRing -> coordinates
    final outerBoundary =
        polygonElem.findElements('outerBoundaryIs').firstOrNull;
    if (outerBoundary == null) {
      throw Exception('Polygon missing outerBoundaryIs');
    }

    final linearRing = outerBoundary.findElements('LinearRing').firstOrNull;
    if (linearRing == null) {
      throw Exception('outerBoundaryIs missing LinearRing');
    }

    final coordsElem = linearRing.findElements('coordinates').firstOrNull;
    if (coordsElem == null) {
      throw Exception('LinearRing missing coordinates');
    }

    final coordsText = coordsElem.innerText.trim();
    final tuples = coordsText
        .split(RegExp(r'\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final tuple in tuples) {
      final parts = tuple.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        final alt = parts.length > 2 ? double.tryParse(parts[2]) : null;

        if (lng != null && lat != null) {
          coordinates.add(GeoCoordinate(
            latitude: lat,
            longitude: lng,
            altitude: alt,
          ));
        }
      }
    }

    return FarmBoundary(
      id: id,
      name: name,
      coordinates: coordinates,
    );
  }

  /// Parse Point element to KmlPlacemark
  static KmlPlacemark _parsePoint(
    String id,
    String name,
    xml.XmlElement placemarkElem,
    xml.XmlElement pointElem,
  ) {
    final coordsElem = pointElem.findElements('coordinates').firstOrNull;
    if (coordsElem == null) {
      throw Exception('Point missing coordinates');
    }

    final coordsText = coordsElem.innerText.trim();
    final parts = coordsText.split(',').map((s) => s.trim()).toList();

    if (parts.length < 2) {
      throw Exception('Invalid point coordinates: $coordsText');
    }

    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    final alt = parts.length > 2 ? double.tryParse(parts[2]) : null;

    if (lng == null || lat == null) {
      throw Exception('Could not parse point coordinates: $coordsText');
    }

    final location = GeoCoordinate(
      latitude: lat,
      longitude: lng,
      altitude: alt,
    );

    // Try to extract ExtendedData if present
    final metadata = _parseExtendedData(
      placemarkElem.findElements('ExtendedData').firstOrNull,
    );

    return KmlPlacemark.fromNameAndLocation(
      id: id,
      name: name,
      location: location,
      metadata: metadata,
    );
  }

  /// Parse ExtendedData (custom data fields)
  static Map<String, dynamic>? _parseExtendedData(xml.XmlElement? elem) {
    if (elem == null) return null;

    final data = <String, dynamic>{};
    for (final dataElem in elem.findElements('Data')) {
      final key = dataElem.getAttribute('name');
      final valueElem = dataElem.findElements('value').firstOrNull;
      if (key != null && valueElem != null) {
        data[key] = valueElem.innerText;
      }
    }

    return data.isEmpty ? null : data;
  }
}
