import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../services/iot_hybrid_connectivity_service.dart';
import 'iot_management_screen.dart';

class IotRealtimeDashboardScreen extends StatefulWidget {
  final VoidCallback? onBackToSetup;

  const IotRealtimeDashboardScreen({super.key, this.onBackToSetup});

  @override
  State<IotRealtimeDashboardScreen> createState() => _IotRealtimeDashboardScreenState();
}

class _IotRealtimeDashboardScreenState extends State<IotRealtimeDashboardScreen>
    with SingleTickerProviderStateMixin {
  final IotHybridConnectivityService _service = IotHybridConnectivityService();

  Timer? _pollingTimer;
  bool _isAutoPolling = true;
  bool _isActionExecuting = false;

  // Live Hardware State from ESP32
  int _moisturePercent = 0;
  int _rawAdc = 3200;
  bool _isPumpRunning = false;
  String _mode = 'AUTO'; // 'AUTO' or 'MANUAL'
  int _lowThreshold = 25;
  int _highThreshold = 45;
  bool _activeHigh = true;
  String _lastActionMsg = 'Connecting to ESP32...';

  // Network & Performance
  bool _isConnected = false;
  int _latencyMs = 0;
  DateTime? _lastPollTime;

  // Real-time History & Logs
  final List<int> _moistureHistory = [];
  final List<String> _eventLogs = [];
  static const int _maxHistoryPoints = 30;

  // Animation for pulsing water badge
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Pump stopwatch
  DateTime? _pumpStartTime;
  Timer? _stopwatchTimer;
  int _pumpElapsedSeconds = 0;

  // Collapsible diagnostics
  bool _showDiagnostics = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _pulseController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    _fetchTelemetry();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_isAutoPolling && mounted) {
        _fetchTelemetry();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchTelemetry() async {
    final stopwatch = Stopwatch()..start();
    final data = await _service.fetchLiveHardwareTelemetry();
    stopwatch.stop();

    if (!mounted) return;

    if (data != null) {
      final int mPct = (data['moisture'] is num) ? (data['moisture'] as num).toInt() : 0;
      final int raw = (data['raw'] is num) ? (data['raw'] as num).toInt() : 3200;
      final bool pump = data['pump'] == 1 || data['pump'] == true;
      final String modeStr = (data['mode'] ?? 'AUTO').toString().toUpperCase();
      final int lowT = (data['lowThresh'] is num) ? (data['lowThresh'] as num).toInt() : 25;
      final int highT = (data['highThresh'] is num) ? (data['highThresh'] as num).toInt() : 45;
      final bool actHigh = data['activeHigh'] == 1 || data['activeHigh'] == true;
      final String msg = (data['msg'] ?? '').toString();

      // Track pump duration
      if (pump && !_isPumpRunning) {
        _pumpStartTime = DateTime.now();
        _startStopwatch();
      } else if (!pump && _isPumpRunning) {
        _pumpStartTime = null;
        _stopwatchTimer?.cancel();
        _pumpElapsedSeconds = 0;
      }

      setState(() {
        _isConnected = true;
        _latencyMs = stopwatch.elapsedMilliseconds;
        _lastPollTime = DateTime.now();
        _moisturePercent = mPct;
        _rawAdc = raw;
        _isPumpRunning = pump;
        _mode = modeStr;
        _lowThreshold = lowT;
        _highThreshold = highT;
        _activeHigh = actHigh;

        if (msg.isNotEmpty && msg != _lastActionMsg) {
          _lastActionMsg = msg;
          _addLog(msg);
        }

        // Update history sparkline
        _moistureHistory.add(mPct);
        if (_moistureHistory.length > _maxHistoryPoints) {
          _moistureHistory.removeAt(0);
        }
      });
    } else {
      if (_isConnected) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pumpStartTime != null && mounted) {
        setState(() {
          _pumpElapsedSeconds = DateTime.now().difference(_pumpStartTime!).inSeconds;
        });
      }
    });
  }

  void _addLog(String text) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    _eventLogs.insert(0, '[$timeStr] $text');
    if (_eventLogs.length > 50) {
      _eventLogs.removeLast();
    }
  }

  Future<void> _handlePumpCommand(bool turnOn) async {
    setState(() => _isActionExecuting = true);
    final res = await _service.setPumpState(turnOn);
    if (mounted) {
      setState(() => _isActionExecuting = false);
      if (res.isSuccess) {
        _fetchTelemetry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: kStatusDanger),
        );
      }
    }
  }

  Future<void> _handleToggleMode() async {
    setState(() => _isActionExecuting = true);
    final res = await _service.toggleMode();
    if (mounted) {
      setState(() => _isActionExecuting = false);
      if (res.isSuccess) {
        _fetchTelemetry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: kStatusDanger),
        );
      }
    }
  }

  Future<void> _handleToggleInvert() async {
    setState(() => _isActionExecuting = true);
    final res = await _service.toggleRelayInvert();
    if (mounted) {
      setState(() => _isActionExecuting = false);
      if (res.isSuccess) {
        _fetchTelemetry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: kStatusDanger),
        );
      }
    }
  }

  Future<void> _handleQuickPulse() async {
    setState(() => _isActionExecuting = true);
    final res = await _service.pulseWaterSeconds(3);
    if (mounted) {
      setState(() => _isActionExecuting = false);
      if (res.isSuccess) {
        _fetchTelemetry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: kStatusDanger),
        );
      }
    }
  }

  Future<void> _handleTestNotification() async {
    setState(() => _isActionExecuting = true);
    final res = await _service.testConnectionAndNotify();
    if (mounted) {
      setState(() => _isActionExecuting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                res.isSuccess ? Icons.notifications_active_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res.isSuccess
                      ? '🔔 ${res.message} (${res.data?['channel'] ?? "Alert Bridge"})'
                      : '❌ ${res.message}',
                ),
              ),
            ],
          ),
          backgroundColor: res.isSuccess ? kStatusSuccess : kStatusDanger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _goToSetup() {
    if (widget.onBackToSetup != null) {
      widget.onBackToSetup!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const IotManagementScreen()),
      );
    }
  }

  Color _getMoistureColor(int pct) {
    if (pct < _lowThreshold) return kStatusDanger;
    if (pct >= _highThreshold) return kStatusInfo;
    return kStatusSuccess;
  }

  String _getMoistureStatusLabel(int pct) {
    if (pct < _lowThreshold) return 'SOIL DRY';
    if (pct >= _highThreshold) return 'SOIL WET';
    return 'SOIL OPTIMAL';
  }

  String _getMoistureTip(int pct) {
    if (pct < _lowThreshold) return 'Soil is dry! Water plant now or keep Auto-Watering enabled.';
    if (pct >= _highThreshold) return 'Soil is fully saturated with ample hydration.';
    return 'Moisture is healthy and optimal for plant growth.';
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = _mode == 'AUTO';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetchTelemetry,
        color: kPrimaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(kDefaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Header Pill
              _buildLiveConnectionBar(),
              const SizedBox(height: 16),

              // 2. Primary Moisture Gauge Card with Beginner Advice
              _buildMoistureGaugeCard(),
              const SizedBox(height: 16),

              // 3. Live Pump Status & Watering Stopwatch
              _buildPumpStatusCard(),
              const SizedBox(height: 16),

              // 4. Beginner-Friendly Controls (Quick Water + Operating Mode)
              _buildControlsCard(isAuto),
              const SizedBox(height: 16),

              // 5. Collapsible Advanced Diagnostics & Telemetry
              _buildDiagnosticsAccordion(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveConnectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? kStatusSuccess : kStatusDanger,
              boxShadow: [
                BoxShadow(
                  color: (_isConnected ? kStatusSuccess : kStatusDanger).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isConnected ? 'LIVE LINK ACTIVE' : 'CONNECTING / OFFLINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? kStatusSuccess : kStatusDanger,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isConnected) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${_latencyMs}ms)',
                        style: const TextStyle(fontSize: 11, color: kTextSecondary),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Connected: ${_service.targetDeviceIp}${_lastPollTime != null ? " • ${_lastPollTime!.minute.toString().padLeft(2, '0')}:${_lastPollTime!.second.toString().padLeft(2, '0')}" : ""}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isAutoPolling ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
              color: kPrimaryColor,
            ),
            tooltip: _isAutoPolling ? 'Pause Live Polling' : 'Resume Live Polling',
            onPressed: () {
              setState(() {
                _isAutoPolling = !_isAutoPolling;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kPrimaryColor),
            tooltip: 'Configure Wi-Fi & IP',
            onPressed: _goToSetup,
          ),
        ],
      ),
    );
  }

  Widget _buildMoistureGaugeCard() {
    final statusColor = _getMoistureColor(_moisturePercent);
    final statusLabel = _getMoistureStatusLabel(_moisturePercent);
    final tipText = _getMoistureTip(_moisturePercent);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kBorderSubtle),
      ),
      color: kSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Soil Moisture Level',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Giant Moisture Value
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_moisturePercent',
                  style: TextStyle(
                    fontSize: 62,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    height: 1.0,
                  ),
                ),
                const Text(
                  '%',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_moisturePercent / 100.0).clamp(0.0, 1.0),
                minHeight: 14,
                backgroundColor: kBackgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),

            // Friendly Plant Health Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.eco_rounded, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tipText,
                      style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpStatusCard() {
    final isWatering = _isPumpRunning;

    return ScaleTransition(
      scale: isWatering ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWatering ? kStatusSuccess.withValues(alpha: 0.12) : kSurfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isWatering ? kStatusSuccess : kBorderSubtle,
            width: isWatering ? 2 : 1,
          ),
          boxShadow: isWatering
              ? [
                  BoxShadow(
                    color: kStatusSuccess.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWatering ? kStatusSuccess : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWatering ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                color: isWatering ? Colors.white : Colors.grey.shade600,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWatering ? 'PUMP ACTIVE: WATERING' : 'PUMP IDLE: OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isWatering ? kStatusSuccess : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isWatering
                        ? 'Watering plant... (${_pumpElapsedSeconds}s elapsed)'
                        : 'Pump is idle. Soil monitoring active.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isWatering ? kStatusSuccess.withValues(alpha: 0.8) : kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Beginner-Friendly Action Section
  Widget _buildControlsCard(bool isAuto) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorderSubtle),
      ),
      color: kSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Primary Actions: Quick Water & Test Notification
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isActionExecuting ? null : _handleQuickPulse,
                      icon: const Icon(Icons.water_drop_rounded, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '💧 Water Plant (3s)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isActionExecuting ? null : _handleTestNotification,
                      icon: const Icon(Icons.notifications_active_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '🔔 Test Alert',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        backgroundColor: const Color(0xFFFFFBEB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Mode Status & Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAuto
                    ? kStatusSuccess.withValues(alpha: 0.08)
                    : const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAuto
                      ? kStatusSuccess.withValues(alpha: 0.25)
                      : const Color(0xFF2563EB).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAuto ? Icons.auto_mode_rounded : Icons.pan_tool_rounded,
                    color: isAuto ? kStatusSuccess : const Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAuto ? 'AUTO IRRIGATION: ACTIVE' : 'MANUAL OVERRIDE: ACTIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isAuto ? kStatusSuccess : const Color(0xFF2563EB),
                          ),
                        ),
                        Text(
                          isAuto
                              ? 'Automatically waters when moisture < $_lowThreshold%'
                              : 'Automatic sensor watering paused.',
                          style: const TextStyle(fontSize: 11, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isActionExecuting ? null : _handleToggleMode,
                    style: TextButton.styleFrom(
                      foregroundColor: isAuto ? const Color(0xFF2563EB) : kStatusSuccess,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      isAuto ? 'Switch' : 'Set Auto',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // 3. In Manual Mode: Explicit Start/Stop controls
            if (!isAuto) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isActionExecuting ? null : () => _handlePumpCommand(true),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start Pump'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kStatusSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isActionExecuting ? null : () => _handlePumpCommand(false),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Stop Pump'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kStatusDanger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Collapsible Diagnostics Accordion keeping 100% of advanced features
  Widget _buildDiagnosticsAccordion() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorderSubtle),
      ),
      color: kSurfaceColor,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showDiagnostics,
          onExpansionChanged: (val) => setState(() => _showDiagnostics = val),
          leading: const Icon(Icons.analytics_outlined, color: kTextSecondary),
          title: const Text(
            'Hardware Diagnostics & Log',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
          ),
          subtitle: const Text(
            'Sparkline trend, relay polarity, raw ADC, and event log',
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: kBorderSubtle),
                  const SizedBox(height: 6),

                  // Sparkline Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Moisture Rolling Trend (30s)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextPrimary),
                      ),
                      Text(
                        '${_moistureHistory.length} samples',
                        style: const TextStyle(fontSize: 11, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sparkline
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklineChartPainter(
                        data: _moistureHistory,
                        lowThresh: _lowThreshold,
                        highThresh: _highThreshold,
                        lineColor: kPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Raw ADC & Cutoff Markers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Auto-Trigger: <$_lowThreshold%',
                          style: const TextStyle(fontSize: 11, color: kStatusDanger, fontWeight: FontWeight.bold)),
                      Text('Raw ADC: $_rawAdc',
                          style: const TextStyle(fontSize: 11, color: kTextSecondary, fontFamily: 'monospace')),
                      Text('Cutoff: ≥$_highThreshold%',
                          style: const TextStyle(fontSize: 11, color: kStatusSuccess, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Relay Invert polarity
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionExecuting ? null : _handleToggleInvert,
                          icon: const Icon(Icons.swap_vert_rounded, size: 16),
                          label: Text(_activeHigh ? 'Relay Polarity: Active HIGH' : 'Relay Polarity: Active LOW'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextSecondary,
                            side: const BorderSide(color: kBorderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hardware Event Log
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📜 HARDWARE EVENT LOG',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _eventLogs.clear();
                          });
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: kTextSecondary, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: _eventLogs.isEmpty
                        ? Text(
                            'Ready. Monitoring soil moisture...\nLast: $_lastActionMsg',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                          )
                        : ListView.builder(
                            itemCount: _eventLogs.length,
                            itemBuilder: (ctx, idx) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.5),
                                child: Text(
                                  _eventLogs[idx],
                                  style: TextStyle(
                                    color: _eventLogs[idx].contains('OPENED')
                                        ? const Color(0xFF4ADE80)
                                        : (_eventLogs[idx].contains('CLOSED')
                                            ? const Color(0xFFF87171)
                                            : const Color(0xFF38BDF8)),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Sparkline chart painter matching IoT_Arduino.ino canvas styling
class _SparklineChartPainter extends CustomPainter {
  final List<int> data;
  final int lowThresh;
  final int highThresh;
  final Color lineColor;

  _SparklineChartPainter({
    required this.data,
    required this.lowThresh,
    required this.highThresh,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    final borderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(10)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(10)),
      borderPaint,
    );

    // Draw horizontal grid lines (0%, 25%, 50%, 75%, 100%)
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;

    for (int yVal = 0; yVal <= 100; yVal += 25) {
      final y = size.height - (yVal / 100.0) * (size.height - 20) - 10;
      canvas.drawLine(Offset(25, y), Offset(size.width - 10, y), gridPaint);
    }

    // Draw Low Threshold line (Red dashed)
    final lowY = size.height - (lowThresh / 100.0) * (size.height - 20) - 10;
    final redPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(25, lowY), Offset(size.width - 10, lowY), redPaint);

    // Draw High Threshold line (Green dashed)
    final highY = size.height - (highThresh / 100.0) * (size.height - 20) - 10;
    final greenPaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(25, highY), Offset(size.width - 10, highY), greenPaint);

    if (data.length < 2) return;

    final path = Path();
    final step = (size.width - 35) / (_SparklineChartPainter._maxPoints - 1);

    for (int i = 0; i < data.length; i++) {
      final x = 25 + i * step;
      final y = size.height - (data[i] / 100.0) * (size.height - 20) - 10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Line stroke
    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Area fill
    final fillPath = Path.from(path)
      ..lineTo(25 + (data.length - 1) * step, size.height - 10)
      ..lineTo(25, size.height - 10)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  static const int _maxPoints = 30;

  @override
  bool shouldRepaint(covariant _SparklineChartPainter oldDelegate) => true;
}
