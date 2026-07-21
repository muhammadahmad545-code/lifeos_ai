import 'package:dio/dio.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.city,
    required this.temperatureC,
    required this.condition,
    required this.windKmh,
    required this.isFallback,
  });

  final String city;
  final double temperatureC;
  final String condition;
  final double windKmh;
  final bool isFallback;

  String get summary => '${temperatureC.round()}° · $condition';
}

class WeatherService {
  WeatherService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<WeatherSnapshot> fetchForCity(String city) async {
    final String query = city.trim().isEmpty ? 'Lahore' : city.trim();
    try {
      final Response<dynamic> geo = await _dio.get<dynamic>(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: <String, dynamic>{'name': query, 'count': 1},
      );
      final List<dynamic>? results = (geo.data as Map<String, dynamic>?)?['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return _fallback(query);
      }
      final Map<String, dynamic> place = results.first as Map<String, dynamic>;
      final double lat = (place['latitude'] as num).toDouble();
      final double lon = (place['longitude'] as num).toDouble();
      final String name = (place['name'] as String?) ?? query;

      final Response<dynamic> forecast = await _dio.get<dynamic>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: <String, dynamic>{
          'latitude': lat,
          'longitude': lon,
          'current_weather': true,
        },
      );
      final Map<String, dynamic>? current =
          (forecast.data as Map<String, dynamic>?)?['current_weather'] as Map<String, dynamic>?;
      if (current == null) {
        return _fallback(name);
      }

      return WeatherSnapshot(
        city: name,
        temperatureC: (current['temperature'] as num).toDouble(),
        condition: _mapWeatherCode((current['weathercode'] as num?)?.toInt() ?? 0),
        windKmh: (current['windspeed'] as num?)?.toDouble() ?? 0,
        isFallback: false,
      );
    } catch (_) {
      return _fallback(query);
    }
  }

  WeatherSnapshot _fallback(String city) {
    final int hour = DateTime.now().hour;
    final double temp = hour < 6
        ? 18
        : hour < 12
            ? 24
            : hour < 18
                ? 29
                : 22;
    return WeatherSnapshot(
      city: city,
      temperatureC: temp,
      condition: hour < 18 ? 'Partly cloudy' : 'Clear night',
      windKmh: 8,
      isFallback: true,
    );
  }

  String _mapWeatherCode(int code) {
    if (code == 0) {
      return 'Clear';
    }
    if (code <= 3) {
      return 'Partly cloudy';
    }
    if (code <= 48) {
      return 'Foggy';
    }
    if (code <= 67) {
      return 'Rain';
    }
    if (code <= 77) {
      return 'Snow';
    }
    if (code <= 82) {
      return 'Showers';
    }
    if (code >= 95) {
      return 'Thunderstorm';
    }
    return 'Cloudy';
  }
}
