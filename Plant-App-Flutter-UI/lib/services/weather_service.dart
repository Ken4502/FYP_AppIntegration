import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature; // °C
  final int relativeHumidity; // %
  final double rainAmount; // mm
  final int precipitationProbability; // %
  final bool isRaining;
  final String weatherCondition;
  final String weatherIcon;
  final String locationName;
  final DateTime timestamp;

  const WeatherData({
    required this.temperature,
    required this.relativeHumidity,
    required this.rainAmount,
    required this.precipitationProbability,
    required this.isRaining,
    required this.weatherCondition,
    required this.weatherIcon,
    this.locationName = 'Urban Sanctuary Area',
    required this.timestamp,
  });

  bool get isRainGuardActive => isRaining || precipitationProbability >= 60 || rainAmount > 0.5;

  String get rainGuardMessage {
    if (isRaining) {
      return '🌧️ Active Rain ($rainAmount mm) • Auto-Watering Suspended to Prevent Overwatering';
    } else if (precipitationProbability >= 60) {
      return '☁️ High Rain Forecast ($precipitationProbability%) • Smart Eco-Watering Pause Active';
    } else {
      return '☀️ Clear Weather • Species-Calibrated Irrigation Active';
    }
  }
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  WeatherData? _cachedWeather;
  WeatherData? get currentWeather => _cachedWeather;

  /// Fetch live real-time local weather from Open-Meteo REST API (No API key required)
  Future<WeatherData> fetchLocalWeather({
    double latitude = 3.1390, // Local coordinates default
    double longitude = 101.6869,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=precipitation_probability,relative_humidity_2m,rain&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final currentWeatherMap = data['current_weather'] as Map<String, dynamic>? ?? {};
        final hourly = data['hourly'] as Map<String, dynamic>? ?? {};

        final temp = (currentWeatherMap['temperature'] as num?)?.toDouble() ?? 28.5;
        final weatherCode = (currentWeatherMap['weathercode'] as num?)?.toInt() ?? 0;

        final probList = hourly['precipitation_probability'] as List?;
        final rainList = hourly['rain'] as List?;
        final humList = hourly['relative_humidity_2m'] as List?;

        final prob = (probList != null && probList.isNotEmpty && probList[0] is num)
            ? (probList[0] as num).toInt()
            : 20;

        final rainMm = (rainList != null && rainList.isNotEmpty && rainList[0] is num)
            ? (rainList[0] as num).toDouble()
            : 0.0;

        final hum = (humList != null && humList.isNotEmpty && humList[0] is num)
            ? (humList[0] as num).toInt()
            : 75;

        // WMO Weather Codes: 51,53,55 = Drizzle; 61,63,65 = Rain; 80,81,82 = Showers; 95,96,99 = Thunderstorm
        final bool isRainingCode = weatherCode >= 51 && weatherCode <= 99;
        final bool isRaining = isRainingCode || rainMm > 0.2;

        String condition = 'Sunny / Clear';
        String icon = '☀️';

        if (weatherCode >= 95) {
          condition = 'Thunderstorm';
          icon = '⛈️';
        } else if (weatherCode >= 80) {
          condition = 'Rain Showers';
          icon = '🌧️';
        } else if (weatherCode >= 61) {
          condition = 'Moderate Rain';
          icon = '🌧️';
        } else if (weatherCode >= 51) {
          condition = 'Light Drizzle';
          icon = '🌦️';
        } else if (weatherCode >= 1 && weatherCode <= 3) {
          condition = 'Partly Cloudy';
          icon = '⛅';
        }

        final weather = WeatherData(
          temperature: temp,
          relativeHumidity: hum,
          rainAmount: rainMm,
          precipitationProbability: prob,
          isRaining: isRaining,
          weatherCondition: condition,
          weatherIcon: icon,
          timestamp: DateTime.now(),
        );

        _cachedWeather = weather;
        return weather;
      }
    } catch (_) {}

    final fallback = WeatherData(
      temperature: 29.0,
      relativeHumidity: 70,
      rainAmount: 0.0,
      precipitationProbability: 15,
      isRaining: false,
      weatherCondition: 'Fair / Clear Sky',
      weatherIcon: '⛅',
      timestamp: DateTime.now(),
    );
    _cachedWeather = fallback;
    return fallback;
  }
}
