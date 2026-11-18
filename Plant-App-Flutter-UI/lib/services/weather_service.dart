import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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

  Map<String, dynamic> toJson() => {
    'city': city,
    'region': region,
    'country': country,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    city: json['city'] as String? ?? '',
    region: json['region'] as String? ?? '',
    country: json['country'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 3.1390,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 101.6869,
  );
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

  /// Quick-select popular cities in Malaysia and neighboring regions
  static const List<UserLocation> popularCities = [
    UserLocation(city: 'Kuala Lumpur', region: 'Federal Territory', country: 'Malaysia', latitude: 3.1390, longitude: 101.6869),
    UserLocation(city: 'Petaling Jaya', region: 'Selangor', country: 'Malaysia', latitude: 3.1073, longitude: 101.6067),
    UserLocation(city: 'Subang Jaya', region: 'Selangor', country: 'Malaysia', latitude: 3.0438, longitude: 101.5806),
    UserLocation(city: 'Shah Alam', region: 'Selangor', country: 'Malaysia', latitude: 3.0738, longitude: 101.5183),
    UserLocation(city: 'Klang', region: 'Selangor', country: 'Malaysia', latitude: 3.0449, longitude: 101.4456),
    UserLocation(city: 'Puchong', region: 'Selangor', country: 'Malaysia', latitude: 3.0333, longitude: 101.6167),
    UserLocation(city: 'Cyberjaya / Putrajaya', region: 'Selangor', country: 'Malaysia', latitude: 2.9213, longitude: 101.6559),
    UserLocation(city: 'George Town', region: 'Penang', country: 'Malaysia', latitude: 5.4141, longitude: 100.3288),
    UserLocation(city: 'Bayan Lepas', region: 'Penang', country: 'Malaysia', latitude: 5.2954, longitude: 100.2642),
    UserLocation(city: 'Johor Bahru', region: 'Johor', country: 'Malaysia', latitude: 1.4927, longitude: 103.7414),
    UserLocation(city: 'Ipoh', region: 'Perak', country: 'Malaysia', latitude: 4.5975, longitude: 101.0901),
    UserLocation(city: 'Melaka', region: 'Melaka', country: 'Malaysia', latitude: 2.1896, longitude: 102.2501),
    UserLocation(city: 'Seremban', region: 'Negeri Sembilan', country: 'Malaysia', latitude: 2.7297, longitude: 101.9381),
    UserLocation(city: 'Kuantan', region: 'Pahang', country: 'Malaysia', latitude: 3.8077, longitude: 103.3260),
    UserLocation(city: 'Kota Kinabalu', region: 'Sabah', country: 'Malaysia', latitude: 5.9804, longitude: 116.0735),
    UserLocation(city: 'Kuching', region: 'Sarawak', country: 'Malaysia', latitude: 1.5533, longitude: 110.3592),
  ];

  /// Pinpoints the user's city via the phone's physical hardware GPS/Location sensor
  Future<UserLocation?> getDeviceGpsLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[WEATHER] GPS service is disabled on device');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[WEATHER] GPS permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[WEATHER] GPS permission denied forever');
        return null;
      }

      // Fast, balanced query for city-level accuracy
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );

      debugPrint('[WEATHER] GPS coordinates: ${position.latitude}, ${position.longitude}');
      final resolved = await reverseGeocodeCoordinates(position.latitude, position.longitude);
      if (resolved != null) {
        _cachedLocation = resolved;
        return resolved;
      }
    } catch (e) {
      debugPrint('[WEATHER] Error fetching phone GPS location: $e');
    }
    return null;
  }

  /// Reverse geocode GPS coordinates into City, State, Country
  Future<UserLocation?> reverseGeocodeCoordinates(double lat, double lon) async {
    // 1. Primary: BigDataCloud reverse geocode client API (fast, clean town/locality resolution)
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        String city = (data['locality'] as String?)?.trim() ?? '';
        if (city.isEmpty) city = (data['city'] as String?)?.trim() ?? '';
        final region = (data['principalSubdivision'] as String?)?.trim() ?? '';
        final country = (data['countryName'] as String?)?.trim() ?? '';

        if (city.isNotEmpty || region.isNotEmpty) {
          return UserLocation(
            city: city.isNotEmpty ? city : region,
            region: region,
            country: country,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (_) {}

    // 2. Secondary fallback: Nominatim OpenStreetMap
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final res = await http.get(url, headers: {'User-Agent': 'UrbanGreen-App/1.0'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        String city = (address['city'] as String?)?.trim() ??
            (address['town'] as String?)?.trim() ??
            (address['municipality'] as String?)?.trim() ??
            (address['suburb'] as String?)?.trim() ??
            '';
        final state = (address['state'] as String?)?.trim() ?? '';
        final country = (address['country'] as String?)?.trim() ?? '';

        if (city.isNotEmpty || state.isNotEmpty) {
          return UserLocation(
            city: city.isNotEmpty ? city : state,
            region: state,
            country: country,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (_) {}

    return UserLocation(
      city: 'Local Area',
      region: '',
      country: '',
      latitude: lat,
      longitude: lon,
    );
  }

  /// Search cities worldwide with exact coordinates using Open-Meteo Geocoding API
  Future<List<UserLocation>> searchCities(String query) async {
    final q = query.trim();
    if (q.isEmpty) return popularCities;

    try {
      final encoded = Uri.encodeComponent(q);
      final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=10&language=en&format=json');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.map((item) {
            final map = item as Map<String, dynamic>;
            return UserLocation(
              city: (map['name'] as String?)?.trim() ?? '',
              region: (map['admin1'] as String?)?.trim() ?? '',
              country: (map['country'] as String?)?.trim() ?? '',
              latitude: (map['latitude'] as num?)?.toDouble() ?? 3.1390,
              longitude: (map['longitude'] as num?)?.toDouble() ?? 101.6869,
            );
          }).toList();
        }
      }
    } catch (_) {}

    // Filter popular cities as local fallback
    final lowerQ = q.toLowerCase();
    return popularCities.where((c) =>
      c.city.toLowerCase().contains(lowerQ) ||
      c.region.toLowerCase().contains(lowerQ) ||
      c.displayName.toLowerCase().contains(lowerQ)
    ).toList();
  }

  /// Manually select a city and immediately fetch its live weather
  Future<WeatherData> selectCity(UserLocation location) async {
    _cachedLocation = location;
    return fetchLocalWeather(
      latitude: location.latitude,
      longitude: location.longitude,
      locationName: location.displayName,
      forceRefreshLocation: false,
    );
  }

  /// Resolves the user's city: First via physical phone GPS, then fallback to IP/Wi-Fi
  Future<UserLocation> resolveUserLocation({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLocation != null) {
      return _cachedLocation!;
    }

    // 1. FIRST PRIORITY: Phone's physical hardware GPS/Location sensor
    final gpsLoc = await getDeviceGpsLocation();
    if (gpsLoc != null) {
      debugPrint('[WEATHER] Using phone GPS location: ${gpsLoc.displayName}');
      _cachedLocation = gpsLoc;
      return gpsLoc;
    }

    // 2. SECOND PRIORITY: Fallback to IP/Wi-Fi Geolocation
    debugPrint('[WEATHER] GPS unavailable; attempting IP/Wi-Fi fallback');
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

    // 3. THIRD PRIORITY: ipapi.co
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

    // 4. Default fallback
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
