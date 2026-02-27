#!/usr/bin/env python3
"""
KML to Dart converter for FarmGenius.
Converts KML zone files into Dart code with FarmZone objects.
Usage: python3 kml_to_dart.py <input_dir> <output_file>
Example: python3 kml_to_dart.py assets/farm_data lib/models/generated/farm_zones.dart
"""

import xml.etree.ElementTree as ET
import os
import sys
from pathlib import Path
from typing import List, Dict, Any

# KML namespace
KML_NS = {'kml': 'http://www.opengis.net/kml/2.2'}


def parse_coordinates(coord_string: str) -> List[Dict[str, float]]:
    """Parse KML coordinates string into list of lat/lng dicts."""
    coords = []
    for coord in coord_string.strip().split():
        if coord:
            parts = coord.split(',')
            if len(parts) >= 2:
                coords.append({
                    'lng': float(parts[0]),
                    'lat': float(parts[1])
                })
    return coords


def parse_kml_file(filepath: str) -> Dict[str, Any]:
    """Parse a single KML file and extract zone data."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Extract placemark
    placemark = root.find('.//kml:Placemark', KML_NS)
    if placemark is None:
        return None

    name = placemark.find('kml:name', KML_NS)
    zone_name = name.text if name is not None else 'Unknown'

    description = placemark.find('kml:description', KML_NS)
    zone_desc = description.text if description is not None else ''

    # Extract extended data (custom attributes)
    extended_data = {}
    for data_elem in placemark.findall('.//kml:Data', KML_NS):
        key = data_elem.get('name', '')
        value_elem = data_elem.find('kml:value', KML_NS)
        if value_elem is not None and value_elem.text:
            extended_data[key] = value_elem.text

    # Extract polygon coordinates
    poly = placemark.find('.//kml:Polygon', KML_NS)
    boundary_coords = []
    if poly is not None:
        outer_ring = poly.find('.//kml:outerBoundaryIs/kml:LinearRing/kml:coordinates', KML_NS)
        if outer_ring is not None and outer_ring.text:
            boundary_coords = parse_coordinates(outer_ring.text)

    return {
        'zone_id': extended_data.get('zone_id', 'unknown'),
        'name': zone_name,
        'description': zone_desc,
        'zone_type': extended_data.get('zone_type', 'unknown'),
        'area_hectares': float(extended_data.get('area_hectares', 0)),
        'boundary': boundary_coords,
        'extended_data': extended_data
    }


def generate_dart_code(zones: List[Dict[str, Any]]) -> str:
    """Generate Dart code for FarmZone objects."""
    code_lines = [
        '// GENERATED FILE - DO NOT EDIT MANUALLY',
        '// This file was generated from KML zone files',
        '// Run: python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated/farm_zones.dart',
        '',
        'import \'package:farmgenius/models/farm_zone.dart\';',
        '',
        'class GeneratedFarmZones {',
        '  static const List<FarmZone> zones = [',
    ]

    for zone in zones:
        # Build boundary list
        boundary_code = 'const [\n'
        for coord in zone['boundary']:
            boundary_code += f'      const GeoPoint(lat: {coord["lat"]}, lng: {coord["lng"]}),\n'
        boundary_code += '    ]'

        # Build extended data map
        extended_data_code = '{\n'
        for key, value in zone['extended_data'].items():
            extended_data_code += f"      '{key}': '{value}',\n"
        extended_data_code += '    }'

        zone_code = f'''    FarmZone(
      id: '{zone["zone_id"]}',
      name: '{zone["name"]}',
      description: '{zone["description"]}',
      type: ZoneType.{zone["zone_type"].upper()},
      areaHectares: {zone["area_hectares"]},
      boundary: {boundary_code},
      metadata: {extended_data_code},
    ),
'''
        code_lines.append(zone_code)

    code_lines.extend([
        '  ];',
        '}',
        ''
    ])

    return '\n'.join(code_lines)


def main():
    if len(sys.argv) < 3:
        print('Usage: python3 kml_to_dart.py <input_dir> <output_file>')
        sys.exit(1)

    input_dir = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.isdir(input_dir):
        print(f'Error: Input directory {input_dir} not found')
        sys.exit(1)

    # Find all KML files
    kml_files = list(Path(input_dir).glob('*.kml'))
    if not kml_files:
        print(f'No KML files found in {input_dir}')
        sys.exit(1)

    print(f'Found {len(kml_files)} KML file(s)')

    # Parse each file
    zones = []
    for kml_file in sorted(kml_files):
        print(f'  Processing {kml_file.name}...')
        zone_data = parse_kml_file(str(kml_file))
        if zone_data:
            zones.append(zone_data)
            print(f'    Loaded zone: {zone_data["zone_id"]}')
        else:
            print(f'    Warning: Could not parse {kml_file.name}')

    # Generate Dart code
    dart_code = generate_dart_code(zones)

    # Write output
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(dart_code)

    print(f'\nGenerated {output_file} with {len(zones)} zone(s)')


if __name__ == '__main__':
    main()
