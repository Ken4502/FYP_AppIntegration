import 'dart:convert';
import 'package:http/http.dart' as http;

class UserLocation {
  final String city;
  final String region;
  final String country;
  final double latitude;
  final double longitude;

  const UserLocation({
    required this.city,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get displayName {
    if (city.isNotEmpty && region.isNotEmpty && city.toLowerCase() != region.toLowerCase()) {
      return '$city, $region';
    } else if (city.isNotEmpty && country.isNotEmpty) {
      return '$city, $country';
    } else if (city.isNotEmpty) {
      return city;
    } else if (region.isNotEmpty) {
      return region;
    }
    return 'Local Area';
  }
}

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
    required this.locationName,
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

  /// Optional OpenWeatherMap API key (if provided, can be used for secondary enrichment)
  static String? openWeatherMapApiKey;

  WeatherData? _cachedWeather;
  WeatherData? get currentWeather => _cachedWeather;

  UserLocation? _cachedLocation;
  UserLocation? get currentLocation => _cachedLocation;

  /// Pinpoints the user's city and state via IP/Wi-Fi geolocation with zero OS popups/permissions.
  Future<UserLocation> resolveUserLocation({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLocation != null) {
      return _cachedLocation!;
    }

    // 1. Primary: ip-api.com (fast, lightweight, highly accurate city & region in Malaysia and worldwide)
    try {
      final uri = Uri.parse('http://ip-api.com/json/?fields=status,country,regionName,city,lat,lon');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final loc = UserLocation(
            city: (data['city'] as String?)?.trim() ?? '',
            region: (data['regionName'] as String?)?.trim() ?? '',
            country: (data['country'] as String?)?.trim() ?? '',
            latitude: (data['lat'] as num?)?.toDouble() ?? 3.1390,
            longitude: (data['lon'] as num?)?.toDouble() ?? 101.6869,
          );
          _cachedLocation = loc;
          return loc;
        }
      }
    } catch (_) {}

    // 2. Secondary Fallback: ipapi.co
    try {
      final uri = Uri.parse('https://ipapi.co/json/');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = UserLocation(
          city: (data['city'] as String?)?.trim() ?? '',
          region: (data['region'] as String?)?.trim() ?? '',
          country: (data['country_name'] as String?)?.trim() ?? '',
          latitude: (data['latitude'] as num?)?.toDouble() ?? 3.1390,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 101.6869,
        );
        _cachedLocation = loc;
        return loc;
      }
    } catch (_) {}

    // 3. Fallback: Default to national metropolitan center
    const fallback = UserLocation(
      city: 'Kuala Lumpur',
      region: 'Federal Territory',
      country: 'Malaysia',
      latitude: 3.1390,
      longitude: 101.6869,
    );
    _cachedLocation = fallback;
    return fallback;
  }

  /// Fetch live real-time local weather for the user's pinpointed city and state.
  /// If [latitude] and [longitude] are omitted, automatically resolves user's current city.
  Future<WeatherData> fetchLocalWeather({
    double? latitude,
    double? longitude,
    String? locationName,
    bool forceRefreshLocation = false,
  }) async {
    UserLocation loc;
    if (latitude != null && longitude != null) {
      loc = UserLocation(
        city: locationName ?? 'Local Area',
        region: '',
        country: '',
        latitude: latitude,
        longitude: longitude,
      );
    } else {
      loc = await resolveUserLocation(forceRefresh: forceRefreshLocation);
    }

    final effectiveLocationName = locationName ?? loc.displayName;

    // 1. Try OpenWeatherMap if an API key has been configured
    if (openWeatherMapApiKey != null && openWeatherMapApiKey!.isNotEmpty) {
      final owmData = await _fetchFromOpenWeatherMap(loc, effectiveLocationName);
      if (owmData != null) {
        _cachedWeather = owmData;
        return owmData;
      }
    }

    // 2. Default & High-Precision Meteorological API: Open-Meteo REST API
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current_weather=true&hourly=precipitation_probability,relative_humidity_2m,rain&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

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

        // WMO Weather Codes: 51..99
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
          condition = weatherCode == 3 ? 'Overcast' : 'Partly Cloudy';
          icon = '⛅';
        } else if (weatherCode == 45 || weatherCode == 48) {
          condition = 'Foggy';
          icon = '🌫️';
        }

        final weather = WeatherData(
          temperature: temp,
          relativeHumidity: hum,
          rainAmount: rainMm,
          precipitationProbability: prob,
          isRaining: isRaining,
          weatherCondition: condition,
          weatherIcon: icon,
          locationName: effectiveLocationName,
          timestamp: DateTime.now(),
        );

        _cachedWeather = weather;
        return weather;
      }
    } catch (_) {}

    // Fallback if network fails
    final fallback = WeatherData(
      temperature: 28.0,
      relativeHumidity: 75,
      rainAmount: 0.0,
      precipitationProbability: 15,
      isRaining: false,
      weatherCondition: 'Partly Cloudy',
      weatherIcon: '⛅',
      locationName: effectiveLocationName,
      timestamp: DateTime.now(),
    );
    _cachedWeather = fallback;
    return fallback;
  }

  /// Optional helper to fetch from OpenWeatherMap API if API key is provided
  Future<WeatherData?> _fetchFromOpenWeatherMap(UserLocation loc, String locationName) async {
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${loc.latitude}&lon=${loc.longitude}&units=metric&appid=$openWeatherMapApiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final main = data['main'] as Map<String, dynamic>? ?? {};
        final weatherList = data['weather'] as List?;
        final weatherFirst = (weatherList != null && weatherList.isNotEmpty)
            ? weatherList[0] as Map<String, dynamic>? ?? {}
            : {};
        final rain = data['rain'] as Map<String, dynamic>? ?? {};

        final temp = (main['temp'] as num?)?.toDouble() ?? 28.0;
        final hum = (main['humidity'] as num?)?.toInt() ?? 75;
        final rainMm = (rain['1h'] as num?)?.toDouble() ?? (rain['3h'] as num?)?.toDouble() ?? 0.0;
        final condition = (weatherFirst['main'] as String?) ?? 'Clear';
        final desc = (weatherFirst['description'] as String?) ?? condition;

        String icon = '☀️';
        bool isRaining = false;
        if (condition.toLowerCase().contains('rain') || condition.toLowerCase().contains('drizzle')) {
          icon = '🌧️';
          isRaining = true;
        } else if (condition.toLowerCase().contains('thunderstorm')) {
          icon = '⛈️';
          isRaining = true;
        } else if (condition.toLowerCase().contains('cloud')) {
          icon = '⛅';
        }

        return WeatherData(
          temperature: temp,
          relativeHumidity: hum,
          rainAmount: rainMm,
          precipitationProbability: isRaining ? 80 : 20,
          isRaining: isRaining,
          weatherCondition: desc[0].toUpperCase() + desc.substring(1),
          weatherIcon: icon,
          locationName: locationName,
          timestamp: DateTime.now(),
        );
      }
    } catch (_) {}
    return null;
  }
}
