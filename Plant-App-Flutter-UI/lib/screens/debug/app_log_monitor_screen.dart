import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../services/app_logger_service.dart';

class AppLogMonitorScreen extends StatefulWidget {
  const AppLogMonitorScreen({super.key});

  @override
  State<AppLogMonitorScreen> createState() => _AppLogMonitorScreenState();
}

class _AppLogMonitorScreenState extends State<AppLogMonitorScreen> {
  final AppLoggerService _logger = AppLoggerService();
  LogCategory? _selectedCategory;
  LogSeverity? _selectedSeverity;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyLogsToClipboard() {
    final text = _logger.exportAsText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 All app debug logs copied to clipboard!'),
        backgroundColor: kPrimaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate terminal bg
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'App Behavior Log Monitor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Live activity stream • Debugging & telemetry analytics',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 20),
              tooltip: 'Copy Logs',
              onPressed: _copyLogsToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFF43F5E), size: 22),
              tooltip: 'Clear Logs',
              onPressed: () => setState(() => _logger.clear()),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _logger,
        builder: (context, _) {
          final filteredLogs = _logger.filter(
            category: _selectedCategory,
            severity: _selectedSeverity,
            query: _searchQuery,
          );

          return Column(
            children: [
              // Search & Quick Category Filter Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: const Color(0xFF1E293B),
                child: Column(
                  children: [
                    // Search Input
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search logs by tag, message, or category...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    // Category Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL (${_logger.logs.length})', null, _selectedCategory == null),
                          const SizedBox(width: 6),
                          ...LogCategory.values.map((cat) {
                            final count = _logger.logs.where((l) => l.category == cat).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: _buildCategoryChip(cat, count),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Log Stream Counter Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filteredLogs.length} entries',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE MONITOR',
                          style: TextStyle(fontSize: 10, color: Color(0xFF34D399), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFF334155)),

              // Terminal Log View
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bug_report_outlined, size: 48, color: Color(0xFF475569)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No logs match your filter "$_searchQuery"' : 'No app behavior logs recorded yet.',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          return _buildLogTile(log);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, LogCategory? category, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(LogCategory category, int count) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = isSelected ? null : category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? category.name == 'iot' ? const Color(0xFF10B981) : const Color(0xFF3B82F6) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 12,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              '${category.name.toUpperCase()} ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(LogCategory cat) {
    switch (cat) {
      case LogCategory.iot:
        return Icons.sensors_rounded;
      case LogCategory.http:
        return Icons.http_rounded;
      case LogCategory.plant:
        return Icons.local_florist_rounded;
      case LogCategory.auth:
        return Icons.lock_person_rounded;
      case LogCategory.store:
        return Icons.shopping_bag_rounded;
      case LogCategory.system:
        return Icons.developer_board_rounded;
    }
  }

  Widget _buildLogTile(AppLogEntry log) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: log.severity == LogSeverity.error
              ? const Color(0xFFF43F5E).withOpacity(0.5)
              : log.severity == LogSeverity.warning
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: log.categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: log.categoryColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(log.categoryIcon, size: 10, color: log.categoryColor),
                    const SizedBox(width: 3),
                    Text(
                      log.categoryName,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: log.categoryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Severity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: log.severityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.severityName,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: log.severityColor),
                ),
              ),
              const SizedBox(width: 8),

              // Tag
              Expanded(
                child: Text(
                  '[${log.tag}]',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Timestamp
              Text(
                log.formattedTime,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Message
          SelectableText(
            log.message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFF8FAFC),
              fontFamily: 'monospace',
              height: 1.3,
            ),
          ),

          // Metadata
          if (log.metadata != null && log.metadata!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                'Data: ${log.metadata}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
