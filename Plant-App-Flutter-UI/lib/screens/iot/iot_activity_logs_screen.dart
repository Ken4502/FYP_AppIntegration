import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/iot_device_model.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import 'iot_details_screen.dart';

class IotActivityLogsScreen extends StatefulWidget {
  final VoidCallback? onBackToSetup;

  const IotActivityLogsScreen({super.key, this.onBackToSetup});

  @override
  State<IotActivityLogsScreen> createState() => _IotActivityLogsScreenState();
}

class _IotActivityLogsScreenState extends State<IotActivityLogsScreen> {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();
  IotLogType? _selectedCategory; // null = all
  String? _selectedDeviceId; // null = all IoT devices
  String? _selectedDeviceName;
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  List<Map<String, String>> _extractKnownDevices(List<IotActivityLog> logs) {
    final Map<String, String> deviceMap = {};

    // 1. Devices registered in the service
    for (final dev in _service.connectedIotDevices) {
      if (dev.id.isNotEmpty) {
        deviceMap[dev.id] = dev.name;
      }
    }

    // 2. Active registered host device
    if (_service.registeredDeviceId.isNotEmpty) {
      deviceMap[_service.registeredDeviceId] = _service.registeredDeviceName;
    }

    // 3. Any device IDs found in the activity logs
    for (final log in logs) {
      if (log.deviceId.isNotEmpty && !deviceMap.containsKey(log.deviceId)) {
        deviceMap[log.deviceId] = log.deviceName;
      }
    }

    return deviceMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  List<IotActivityLog> _filterLogs(List<IotActivityLog> allLogs) {
    return allLogs.where((log) {
      // 1. Device filter
      if (_selectedDeviceId != null && log.deviceId != _selectedDeviceId) {
        return false;
      }
      // 2. Category filter
      if (_selectedCategory != null && log.type != _selectedCategory) {
        return false;
      }
      // 3. Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = log.title.toLowerCase().contains(q);
        final matchDetail = log.detail.toLowerCase().contains(q);
        final matchDevice = log.deviceName.toLowerCase().contains(q) ||
            log.deviceId.toLowerCase().contains(q);
        final matchCategory = log.categoryLabel.toLowerCase().contains(q);
        if (!matchTitle && !matchDetail && !matchDevice && !matchCategory) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<List<IotActivityLog>>(
          valueListenable: _service.activityLogsNotifier,
          builder: (context, allLogs, _) {
            final knownDevices = _extractKnownDevices(allLogs);
            final filteredLogs = _filterLogs(allLogs);

            return Column(
              children: [
                // Search Bar (if opened)
                if (_isSearchOpen) _buildSearchBar(),

                // Device Filter Selector Row (All Devices vs Specific IoT)
                _buildDeviceFilterRow(knownDevices),

                // Category Filter Chips
                _buildCategoryFilterChips(),

                // Header with Count and Permanent Audit Badge (no delete/clear!)
                _buildHeaderRow(filteredLogs.length),

                // List of Activity Logs
                Expanded(
                  child: filteredLogs.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredLogs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) => _buildLogCard(filteredLogs[idx]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: kSurfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search logs (e.g. pump, moisture, alert)...',
                hintStyle: const TextStyle(fontSize: 12, color: kTextSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kPrimaryColor),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: kBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorderSubtle),
                ),
              ),
              style: const TextStyle(fontSize: 12, color: kTextPrimary),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: kTextSecondary),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _isSearchOpen = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceFilterRow(List<Map<String, String>> devices) {
    return Container(
      color: kSurfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 13, color: kTextSecondary),
              const SizedBox(width: 5),
              const Text(
                'FILTER BY IOT DEVICE:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: kTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (!_isSearchOpen)
                InkWell(
                  onTap: () => setState(() => _isSearchOpen = true),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 14, color: kPrimaryColor),
                        SizedBox(width: 3),
                        Text(
                          'Search',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_selectedDeviceId != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDeviceId = null;
                      _selectedDeviceName = null;
                    });
                  },
                  child: const Text(
                    'Clear Filter',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All IoT Devices" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      Icons.language_rounded,
                      size: 14,
                      color: _selectedDeviceId == null ? Colors.white : kPrimaryColor,
                    ),
                    label: Text(
                      'All IoT Devices',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedDeviceId == null ? FontWeight.bold : FontWeight.w500,
                        color: _selectedDeviceId == null ? Colors.white : kTextPrimary,
                      ),
                    ),
                    selected: _selectedDeviceId == null,
                    selectedColor: kPrimaryColor,
                    backgroundColor: kBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _selectedDeviceId == null ? kPrimaryColor : kBorderSubtle,
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    onSelected: (_) {
                      setState(() {
                        _selectedDeviceId = null;
                        _selectedDeviceName = null;
                      });
                    },
                  ),
                ),
                // Specific IoT device chips
                ...devices.map((dev) {
                  final isSelected = _selectedDeviceId == dev['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        Icons.developer_board_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : const Color(0xFF0284C7),
                      ),
                      label: Text(
                        '${dev['name']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : kTextPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: kBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0284C7) : kBorderSubtle,
                        ),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onSelected: (_) {
                        setState(() {
                          _selectedDeviceId = dev['id'];
                          _selectedDeviceName = dev['name'];
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    final filters = [
      {'label': 'All Events', 'type': null},
      {'label': '💧 Watering', 'type': IotLogType.watering},
      {'label': '🌱 Sensing', 'type': IotLogType.sensing},
      {'label': '🔔 Alerts', 'type': IotLogType.notifying},
      {'label': '📶 Network', 'type': IotLogType.network},
      {'label': '⚙️ System', 'type': IotLogType.system},
    ];

    return Container(
      color: kSurfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedCategory == f['type'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  f['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : kTextPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: kPrimaryColor,
                backgroundColor: kBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? kPrimaryColor : kBorderSubtle,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = f['type'] as IotLogType?;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Showing $count event${count == 1 ? "" : "s"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary),
              ),
              if (_selectedDeviceId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedDeviceName ?? _selectedDeviceId!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ],
          ),
          // Permanent Audit Trail Indicator (No remove button!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: kTextSecondary),
                SizedBox(width: 4),
                Text(
                  'Permanent Audit Log',
                  style: TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(IotActivityLog log) {
    final clock = _formatClock(log.timestamp);
    final relative = _formatRelativeTime(log.timestamp);
    final isSelectedDevice = _selectedDeviceId == log.deviceId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogDetailModal(log),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelectedDevice
                  ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                  : kBorderSubtle,
              width: isSelectedDevice ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Device Badge & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Device Badge
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedDeviceId == log.deviceId) {
                            _selectedDeviceId = null;
                            _selectedDeviceName = null;
                          } else {
                            _selectedDeviceId = log.deviceId;
                            _selectedDeviceName = log.deviceName;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelectedDevice
                              ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelectedDevice
                                ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.developer_board_rounded,
                              size: 13,
                              color: isSelectedDevice ? const Color(0xFF0284C7) : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                log.deviceName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelectedDevice ? const Color(0xFF0284C7) : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Clock & Relative Time (Never overflows)
                  Text(
                    '$clock • $relative',
                    style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Main Row: Category Icon + Content + Duration Badge + Chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Icon in Circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: log.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(log.icon, color: log.color, size: 18),
                  ),
                  const SizedBox(width: 12),

                  // Middle: Title & Detail
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          log.detail,
                          style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.3),
                        ),
                        const SizedBox(height: 8),

                        // Badges Row: Category + Duration (if applicable) + Quick View Action
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Category Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.categoryLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: log.color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),

                            // Duration Badge if pump/watering duration exists!
                            if (log.durationSeconds != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_rounded, size: 11, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '⏱️ ${log.durationSeconds}s duration',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Tap to view prompt
                            const Text(
                              'Tap for details ➔',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetailModal(IotActivityLog log) {
    final fullDate =
        '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')} at ${_formatClock(log.timestamp)}';
    final isWatering = log.type == IotLogType.watering || log.durationSeconds != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Icon + Title + Category
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: log.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(log.icon, size: 22, color: log.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${log.categoryLabel} Event • $fullDate',
                          style: const TextStyle(fontSize: 11, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Section 1: IoT Device Specification
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.developer_board_rounded, size: 16, color: kPrimaryColor),
                        SizedBox(width: 6),
                        Text(
                          'IOT DEVICE SPECIFICATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kTextSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Device Name: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                        Flexible(
                          child: Text(
                            log.deviceName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hardware / Device ID: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                        Flexible(
                          child: Text(
                            log.deviceId,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Network Link: ', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                        Text(
                          _service.isRealHardwareConnected ? 'Online (LAN/Cloud)' : 'Local Wi-Fi',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kStatusSuccess),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Section 2: Detailed Event Telemetry & Duration
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'EVENT DETAILS & TELEMETRY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kTextSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      log.detail,
                      style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
                    ),
                    if (isWatering && log.durationSeconds != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop_rounded, size: 20, color: Color(0xFF0284C7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pump Run Duration: ${log.durationSeconds} seconds',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Estimated ~${log.durationSeconds! * 25} ml water delivered to plant root zone.',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action 1: "Filter Only This IoT's Logs"
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.filter_alt_rounded, size: 18),
                label: Text(
                  _selectedDeviceId == log.deviceId
                      ? 'Show All IoT Devices'
                      : 'Show Only "${log.deviceName}" Logs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (_selectedDeviceId == log.deviceId) {
                      _selectedDeviceId = null;
                      _selectedDeviceName = null;
                    } else {
                      _selectedDeviceId = log.deviceId;
                      _selectedDeviceName = log.deviceName;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _selectedDeviceId != null
                            ? 'Showing logs for ${log.deviceName} only.'
                            : 'Showing logs for all IoT devices.',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // Action 2: "Open IoT Configuration & Sensors"
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18, color: kPrimaryColor),
                label: const Text('Open IoT Configuration & Sensors', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  final dev = _service.connectedIotDevices.firstWhere(
                    (d) => d.id == log.deviceId,
                    orElse: () => IotDevice(
                      id: log.deviceId,
                      name: log.deviceName,
                      wifiSsid: _service.registeredHomeSsid,
                      isWifiConnected: true,
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => IotDetailsScreen(device: dev)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 48, color: kPrimaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedDeviceId != null
                  ? 'No Logs for "${_selectedDeviceName ?? _selectedDeviceId}"'
                  : (_searchQuery.isNotEmpty ? 'No Matching Logs' : 'No Activity Logs Found'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _selectedDeviceId != null
                  ? 'No events match the selected filters for this IoT device.'
                  : (_searchQuery.isNotEmpty
                      ? 'No activity entries matched "$_searchQuery".'
                      : 'Hardware events, watering cycles, sensing updates, and notifications will appear here in real time as they occur.'),
              style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (_selectedDeviceId != null || _searchQuery.isNotEmpty || _selectedCategory != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset All Filters'),
                onPressed: () {
                  setState(() {
                    _selectedDeviceId = null;
                    _selectedDeviceName = null;
                    _selectedCategory = null;
                    _searchQuery = '';
                    _searchController.clear();
                    _isSearchOpen = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
