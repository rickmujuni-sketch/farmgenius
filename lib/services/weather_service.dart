import 'package:http/http.dart' as http;
import 'dart:convert';
import 'farm_zone.dart';

/// NASA POWER API weather service
/// Fetches weather data for the farm to enable AI decision-making
class WeatherService {
  static const String _nasaUrl = 'https://power.larc.nasa.gov/api/v1/daily';

  /// Fetch weather data for a location
  /// NASA POWER API returns daily weather data
  static Future<List<WeatherData>> fetchWeatherForecast({
    required double lat,
    required double lng,
    required int days,
  }) async {
    try {
      // Calculate date range (last 30 days for context + forecast)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: 1));

      // Format: yyyyMMdd
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      final params = {
        'parameters': 'T2M,RH2M,PRECTOTCORR,WS2M,GWETROOT', // temp, humidity, precip, wind, soil moisture
        'community': 'ag',
        'longitude': lng.toString(),
        'latitude': lat.toString(),
        'start': startStr,
        'end': endStr,
        'format': 'json',
      };

      final uri = Uri.parse(_nasaUrl).replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseNasaResponse(response.body, lat.toString());
      } else {
        print('NASA POWER API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('WeatherService error: $e');
      return [];
    }
  }

  static List<WeatherData> _parseNasaResponse(String body, String zoneId) {
    final json = jsonDecode(body);
    final properties = json['properties'];
    final params = properties['parameter'];

    final weatherList = <WeatherData>[];

    // NASA returns data in YYYYMMDD format as keys
    final tempData = params['T2M'] as Map<String, dynamic>? ?? {};
    final humidityData = params['RH2M'] as Map<String, dynamic>? ?? {};
    final rainData = params['PRECTOTCORR'] as Map<String, dynamic>? ?? {};
    final windData = params['WS2M'] as Map<String, dynamic>? ?? {};
    final soilMoistData = params['GWETROOT'] as Map<String, dynamic>? ?? {};

    for (final dateStr in tempData.keys) {
      try {
        final date = _parseDate(dateStr);
        final temp = (tempData[dateStr] as num?)?.toDouble() ?? 0.0;
        final humidity = (humidityData[dateStr] as num?)?.toDouble() ?? 50.0;
        final rain = (rainData[dateStr] as num?)?.toDouble() ?? 0.0;
        final wind = (windData[dateStr] as num?)?.toDouble() ?? 0.0;
        final soil = (soilMoistData[dateStr] as num?)?.toDouble() ?? 50.0;

        weatherList.add(WeatherData(
          zoneId: zoneId,
          date: date,
          temperatureC: temp,
          humidity: humidity,
          rainfall: rain,
          windSpeed: wind,
          soilMoisture: soil,
        ));
      } catch (e) {
        print('Error parsing weather for $dateStr: $e');
      }
    }

    return weatherList;
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDate(String dateStr) {
    // dateStr is YYYYMMDD
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
  }

  /// Assess weather risk for a crop activity
  static String assessWeatherRisk({
    required WeatherData weather,
    required ActivityStage activity,
  }) {
    // Simple risk assessment based on activity type
    // In production, use crop-specific thresholds

    if (activity == ActivityStage.GERMINATION) {
      // Germination needs moisture and moderate temperature
      if (weather.soilMoisture < 30) return 'DRY_SOIL';
      if (weather.temperatureC < 15 || weather.temperatureC > 35) return 'TEMP_EXTREME';
    }

    if (activity == ActivityStage.FLOWERING) {
      // Flowering is sensitive to wind and temp
      if (weather.windSpeed > 20) return 'HIGH_WIND';
      if (weather.temperatureC > 32) return 'HEAT_STRESS';
    }

    if (activity == ActivityStage.HARVEST) {
      // Harvest needs dry conditions
      if (weather.rainfall > 5) return 'RAIN_RISK';
    }

    if (weather.humidity > 90 && weather.temperatureC > 25) {
      return 'FUNGAL_RISK'; // Disease pressure
    }

    return 'LOW_RISK';
  }
}
