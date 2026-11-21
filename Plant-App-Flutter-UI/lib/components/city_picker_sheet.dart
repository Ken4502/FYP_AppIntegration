import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/weather_service.dart';

class CityPickerSheet extends StatefulWidget {
  final Function(UserLocation location) onCitySelected;

  const CityPickerSheet({
    super.key,
    required this.onCitySelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(UserLocation location) onCitySelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CityPickerSheet(onCitySelected: onCitySelected),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  List<UserLocation> _searchResults = [];
  bool _isSearching = false;
  bool _isLocatingGps = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchResults = WeatherService.popularCities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = WeatherService.popularCities;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await _weatherService.searchCities(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _useCurrentPhoneGps() async {
    setState(() => _isLocatingGps = true);
    final gpsLoc = await _weatherService.getDeviceGpsLocation();
    if (!mounted) return;
    setState(() => _isLocatingGps = false);

    if (gpsLoc != null) {
      widget.onCitySelected(gpsLoc);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access phone GPS. Please verify location permissions are enabled.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLoc = _weatherService.currentLocation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : kSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your City 📍',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pinpoint city for live weather & RainGuard',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Instant Phone GPS Location Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isLocatingGps ? null : _useCurrentPhoneGps,
                icon: _isLocatingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _isLocatingGps ? 'Detecting Phone Location...' : 'Use Current Phone Location (GPS)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Or search city (e.g. Petaling Jaya, Klang)...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: kPrimaryColor, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Section label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _searchController.text.trim().isEmpty ? 'POPULAR CITIES' : 'SEARCH RESULTS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: kPrimaryColor,
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Cities List
          Expanded(
            child: _searchResults.isEmpty && !_isSearching
                ? Center(
                    child: Text(
                      'No matching cities found.\nTry a different spelling.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 48,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (context, index) {
                      final loc = _searchResults[index];
                      final isCurrent = currentLoc != null &&
                          currentLoc.city.toLowerCase() == loc.city.toLowerCase() &&
                          currentLoc.region.toLowerCase() == loc.region.toLowerCase();

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? kPrimaryColor.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCurrent ? Icons.check_circle_rounded : Icons.location_on_outlined,
                            size: 18,
                            color: isCurrent ? kPrimaryColor : (isDark ? kDarkTextSecondary : kTextSecondary),
                          ),
                        ),
                        title: Text(
                          loc.city,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? kPrimaryColor
                                : (isDark ? kDarkTextPrimary : kTextPrimary),
                          ),
                        ),
                        subtitle: Text(
                          loc.region.isNotEmpty
                              ? '${loc.region}, ${loc.country}'
                              : loc.country,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                        onTap: () {
                          widget.onCitySelected(loc);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
