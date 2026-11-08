import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/data/flora_250_data.dart';
import 'package:urbangreen/models/product_model.dart';

class PlantLibraryScreen extends StatefulWidget {
  const PlantLibraryScreen({super.key});

  @override
  State<PlantLibraryScreen> createState() => _PlantLibraryScreenState();
}

class _PlantLibraryScreenState extends State<PlantLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categoryTabs = [
    'All',
    'Houseplants & Tropicals',
    'Flowers & Ornamentals',
    'Fruits & Vegetables',
    'Herbs & Aromatics',
    'Trees & Palms',
    'Succulents & Cacti',
    'Ferns',
    'Wild & Urban Flora',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCareSheet(BuildContext context, FloraSpecies species) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isNetwork = species.imageUrl.startsWith('http');
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: isNetwork
                            ? Image.network(
                                species.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.spa, size: 36, color: Colors.grey),
                                ),
                              )
                            : Image.asset(
                                species.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.spa, size: 36, color: Colors.grey),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            species.commonName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            species.scientificName,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kAccentMint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              species.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  species.description,
                  style: TextStyle(fontSize: 13, height: 1.45, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Botanical Care Guidelines',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                const SizedBox(height: 10),
                _buildCareRow(
                  icon: Icons.water_drop_rounded,
                  iconColor: Colors.blue.shade600,
                  label: 'Target Soil Moisture',
                  value: '${species.lowMoistureThreshold}% – ${species.highMoistureThreshold}%',
                  subtitle: species.wateringRecommendation,
                ),
                _buildCareRow(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: Colors.amber.shade700,
                  label: 'Sunlight Exposure',
                  value: species.sunlight,
                ),
                _buildCareRow(
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.teal.shade600,
                  label: 'Watering Interval',
                  value: 'Every ${species.wateringIntervalDays} days',
                ),
                _buildCareRow(
                  icon: Icons.device_thermostat_rounded,
                  iconColor: Colors.orange.shade600,
                  label: 'Ideal Temperature',
                  value: species.idealTemperature,
                ),
                _buildCareRow(
                  icon: Icons.pets_rounded,
                  iconColor: species.petToxicity.toLowerCase().contains('non-toxic')
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  label: 'Pet Safety / Toxicity',
                  value: species.petToxicity,
                ),
                _buildCareRow(
                  icon: Icons.grass_rounded,
                  iconColor: Colors.brown.shade600,
                  label: 'Soil Formulation',
                  value: species.soilType,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, species.toPlant());
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add to My Garden',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCareRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: const StandardAppBar(
        title: 'Botanical Flora Library',
        subtitle: 'FloraNet-250 Encyclopedia & Care Guide',
        toolbarHeight: 68,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search 250 species by common or botanical name...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20, color: kPrimaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kBorderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kBorderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Horizontal Category Tabs
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categoryTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = _categoryTabs[idx];
                final isSelected = (cat == 'All' && _selectedCategory == 'All') ||
                    cat == _selectedCategory;

                return ChoiceChip(
                  label: Text(
                    cat == 'All' ? 'All (250)' : cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : kTextPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: kPrimaryColor,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? kPrimaryColor : kBorderSubtle,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Main Botanical List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('plant_supplies')
                  .where('type', isEqualTo: 'Plant')
                  .snapshots(),
              builder: (context, snapshot) {
                // Base 250 verified species
                List<FloraSpecies> allSpecies = List.from(Flora250Data.speciesList);

                // Merge store inventory products if present
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final existingNames = allSpecies
                      .map((x) => x.commonName.toLowerCase())
                      .toSet();

                  for (final doc in snapshot.data!.docs) {
                    final p = Product.fromFirestore(doc);
                    if (!existingNames.contains(p.name.toLowerCase())) {
                      allSpecies.add(
                        FloraSpecies(
                          id: p.id,
                          commonName: p.name,
                          scientificName: p.name,
                          rawName: p.name,
                          category: 'Houseplants & Tropicals',
                          description: p.description.isNotEmpty
                              ? p.description
                              : 'Curated nursery houseplant.',
                          imageUrl: p.imageUrl.isNotEmpty
                              ? p.imageUrl
                              : 'assets/images/image_1.png',
                          lowMoistureThreshold: 25,
                          highMoistureThreshold: 50,
                          wateringIntervalDays: 7,
                          wateringRecommendation: 'Water when top 1-2 inches feel dry.',
                          sunlight: 'Bright indirect light',
                          idealTemperature: '18°C - 26°C',
                          petToxicity: 'Check local toxicity guidelines',
                          soilType: 'Standard well-draining potting soil',
                        ),
                      );
                    }
                  }
                }

                // Filter by category
                List<FloraSpecies> filtered = allSpecies;
                if (_selectedCategory != 'All') {
                  filtered = filtered.where((s) {
                    return s.category.toLowerCase() == _selectedCategory.toLowerCase();
                  }).toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((s) {
                    return s.commonName.toLowerCase().contains(_searchQuery) ||
                        s.scientificName.toLowerCase().contains(_searchQuery) ||
                        s.category.toLowerCase().contains(_searchQuery) ||
                        s.description.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No plants found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No species matched your search criteria in $_selectedCategory.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = 'All';
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset All Filters'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${filtered.length} of ${allSpecies.length} species',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                          Text(
                            'Tap card for care details',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final species = filtered[index];
                          final isNetwork = species.imageUrl.startsWith('http');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: kBorderSubtle),
                            ),
                            elevation: 0.5,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showCareSheet(context, species),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: isNetwork
                                            ? Image.network(
                                                species.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.spa, size: 28, color: Colors.grey),
                                                ),
                                              )
                                            : Image.asset(
                                                species.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.spa, size: 28, color: Colors.grey),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  species.commonName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: kTextPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: kAccentMint.withValues(alpha: 0.7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  species.category.split(' & ').first,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: kPrimaryDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            species.scientificName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          // Micro care badges
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _buildMicroBadge(
                                                '💧 ${species.lowMoistureThreshold}-${species.highMoistureThreshold}%',
                                                Colors.blue.shade50,
                                                Colors.blue.shade800,
                                              ),
                                              _buildMicroBadge(
                                                '🗓️ ${species.wateringIntervalDays}d',
                                                Colors.teal.shade50,
                                                Colors.teal.shade800,
                                              ),
                                              _buildMicroBadge(
                                                species.sunlight.contains('Full')
                                                    ? '☀️ Full sun'
                                                    : '🌤️ Filtered',
                                                Colors.amber.shade50,
                                                Colors.amber.shade900,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Quick Add Button
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        Navigator.pop(context, species.toPlant());
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: kPrimaryColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
