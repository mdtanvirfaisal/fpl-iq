import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _notifications = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getNotifications();
      setState(() {
        _notifications = res;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (!item.read) {
      await ApiService.markNotificationRead(item.id);
      _loadNotifications();
    }
  }

  void _showSettingsDialog() async {
    try {
      final curSettings = await ApiService.getNotificationSettings();
      if (!mounted) return;

      bool ev = curSettings.enablePlayerEvents;
      bool rk = curSettings.enableRankImpact;
      bool inj = curSettings.enableInjuries;
      bool tr = curSettings.enableTransfers;
      bool dl = curSettings.enableDeadline;
      bool qh = curSettings.quietHoursEnabled;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Row(
                children: [
                  Icon(Icons.tune, color: AppTheme.fplGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Alert Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      dense: true,
                      title: const Text('Live Match Events', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Goals, assists, cards for tracked players', style: TextStyle(fontSize: 11)),
                      value: ev,
                      activeThumbColor: AppTheme.fplGreen,
                      onChanged: (val) => setDialogState(() => ev = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Rank Impact Swings', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('High priority delta alerts vs cohorts', style: TextStyle(fontSize: 11)),
                      value: rk,
                      activeThumbColor: AppTheme.fplGreen,
                      onChanged: (val) => setDialogState(() => rk = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Injury & Availability', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Status updates, doubts & suspensions', style: TextStyle(fontSize: 11)),
                      value: inj,
                      activeThumbColor: AppTheme.fplGreen,
                      onChanged: (val) => setDialogState(() => inj = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Market Trends', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Mass transfers in/out notifications', style: TextStyle(fontSize: 11)),
                      value: tr,
                      activeThumbColor: AppTheme.fplGreen,
                      onChanged: (val) => setDialogState(() => tr = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Deadline Countdown', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('24h, 3h, 30m deadline alerts', style: TextStyle(fontSize: 11)),
                      value: dl,
                      activeThumbColor: AppTheme.fplGreen,
                      onChanged: (val) => setDialogState(() => dl = val),
                    ),
                    const Divider(color: AppTheme.surfaceVariant),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Quiet Hours (23:00 - 07:00)', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Mute low & normal alerts overnight', style: TextStyle(fontSize: 11)),
                      value: qh,
                      activeThumbColor: AppTheme.fplCyan,
                      onChanged: (val) => setDialogState(() => qh = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ApiService.updateNotificationSettings(NotificationSettings(
                      enablePlayerEvents: ev,
                      enableRankImpact: rk,
                      enableInjuries: inj,
                      enableTransfers: tr,
                      enableDeadline: dl,
                      quietHoursEnabled: qh,
                    ));
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Feed & Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showSettingsDialog,
            tooltip: 'Notification Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh Alerts',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen))
          : _notifications.isEmpty
              ? const Center(child: Text('No active notifications.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];

                    Color priorityColor;
                    switch (item.priority) {
                      case 'critical':
                        priorityColor = AppTheme.fplPink;
                        break;
                      case 'high':
                        priorityColor = AppTheme.fplGreen;
                        break;
                      case 'normal':
                        priorityColor = Colors.orange;
                        break;
                      default:
                        priorityColor = Colors.grey;
                    }

                    return Card(
                      color: item.read ? AppTheme.surface : AppTheme.surfaceVariant.withValues(alpha: 0.8),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: item.read ? AppTheme.surfaceVariant : priorityColor.withValues(alpha: 0.6),
                          width: item.read ? 1 : 1.5,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _markRead(item),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.priority.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            Text(
                              item.category.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.read ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.body,
                                style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                              ),
                            ],
                          ),
                        ),
                        trailing: item.read
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: priorityColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
