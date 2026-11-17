import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../core/notifications/reminder_health.dart';
import '../../core/notifications/reminder_service.dart';
import '../../shared/extension/context_extension.dart';

/// Everything that decides whether reminders arrive on time, each with a
/// way to fix it, and a test notification to prove it.
@RoutePage()
class ReminderCheckScreen extends StatefulLoggableWidget {
  const ReminderCheckScreen({super.key});

  @override
  State<ReminderCheckScreen> createState() => _ReminderCheckScreenState();
}

class _ReminderCheckScreenState extends State<ReminderCheckScreen>
    with WidgetsBindingObserver {
  final _service = getIt<ReminderService>();
  _Status? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a system settings page
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final status = await _Status.read(_service);
    if (mounted) {
      setState(() => _status = status);
    }
  }

  /// Leaving for system settings shouldn't bring an app-open ad back with us
  Future<void> _leaveApp(Future<void> Function() open) async {
    MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
    await open();
    await _refresh();
  }

  Future<void> _fixNotifications() => _leaveApp(() async {
    await _service.requestNotifications();
    if (!await _service.notificationsEnabled()) {
      await _service.openNotificationSettings();
    }
  });

  Future<void> _sendTest() async {
    if (_status?.notifications == false) {
      await _fixNotifications();
    }
    final sent = await _service.sendTest();
    if (sent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.testSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderCheck)),
      body: status == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Summary(issues: status.issues),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: _divided([
                      _Row(
                        state: status.notifications ? _State.ok : _State.bad,
                        icon: Icons.notifications_active_outlined,
                        title: l10n.notifications,
                        subtitle: status.notifications
                            ? l10n.notificationsOnHint
                            : l10n.notificationsOffHint,
                        action: status.notifications
                            ? null
                            : (l10n.turnOn, _fixNotifications),
                      ),
                      if (Platform.isAndroid)
                        _Row(
                          state: status.exact ? _State.ok : _State.bad,
                          icon: Icons.alarm_rounded,
                          title: l10n.exactAlarmTitle,
                          subtitle: status.exact
                              ? l10n.exactAlarmOnHint
                              : l10n.exactAlarmOffHint,
                          action: status.exact
                              ? null
                              : (
                                  l10n.allowExactAlarms,
                                  () => _leaveApp(_service.requestExactAlarms),
                                ),
                        ),
                      if (Platform.isAndroid)
                        _Row(
                          state: status.device.batteryOptimized
                              ? _State.bad
                              : _State.ok,
                          icon: Icons.battery_saver_rounded,
                          title: l10n.batteryTitle,
                          subtitle: status.device.batteryOptimized
                              ? '${l10n.batteryOnHint}\n${l10n.batteryStep}'
                              : l10n.batteryOffHint,
                          action: status.device.batteryOptimized
                              ? (
                                  l10n.openSettings,
                                  () => _leaveApp(
                                    ReminderHealth.openBatterySettings,
                                  ),
                                )
                              : null,
                        ),
                      if (status.device.oem.autostart)
                        _Row(
                          state: _State.tip,
                          icon: Icons.restart_alt_rounded,
                          title: l10n.autostartTitle(status.device.brandName),
                          subtitle: l10n.autostartHint,
                          action: (
                            l10n.openSettings,
                            () => _leaveApp(ReminderHealth.openAutostart),
                          ),
                        ),
                      if (status.device.oem.lockInRecents)
                        _Row(
                          state: _State.tip,
                          icon: Icons.lock_outline_rounded,
                          title: l10n.lockRecentsTitle,
                          subtitle: l10n.lockRecentsHint,
                        ),
                      if (Platform.isAndroid)
                        _Row(
                          state: status.device.fullScreenAllowed
                              ? _State.ok
                              : _State.tip,
                          icon: Icons.fullscreen_rounded,
                          title: l10n.fullScreenTitle,
                          subtitle: l10n.fullScreenHint,
                          action: status.device.fullScreenAllowed
                              ? null
                              : (
                                  l10n.allowExactAlarms,
                                  () => _leaveApp(_service.requestFullScreen),
                                ),
                        ),
                      if (status.device.oem != Oem.other)
                        ListTile(
                          leading: const Icon(Icons.menu_book_rounded),
                          title: Text(l10n.brandGuide(status.device.brandName)),
                          subtitle: Text(l10n.brandGuideHint),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () => _leaveApp(
                            () => launchUrl(
                              status.device.oem.guideUrl,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                  child: Text(
                    l10n.scheduledInfo(status.pending, status.timeZone),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _sendTest,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(l10n.sendTest),
                ),
              ],
            ),
    );
  }

  List<Widget> _divided(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const Divider(indent: 56, height: 1),
      rows[i],
    ],
  ];
}

class _Status {
  const _Status({
    required this.notifications,
    required this.exact,
    required this.device,
    required this.pending,
    required this.timeZone,
  });

  final bool notifications;
  final bool exact;
  final DeviceReminderInfo device;
  final int pending;
  final String timeZone;

  /// What stops reminders outright or makes them late. Auto-start and
  /// full-screen can't be read back (or only matter for alarm style), so
  /// they're tips rather than issues.
  int get issues => [
    !notifications,
    !exact,
    device.batteryOptimized,
  ].where((bad) => bad).length;

  static Future<_Status> read(ReminderService service) async {
    String zone;
    try {
      zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Exception {
      zone = DateTime.now().timeZoneName;
    }
    return _Status(
      notifications: await service.notificationsEnabled(),
      exact: await service.exactAlarmsAllowed(),
      device: await ReminderHealth.read(),
      pending: await service.pendingCount(),
      timeZone: zone,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.issues});

  final int issues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final good = issues == 0;
    return Card(
      color: good ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              good ? Icons.verified_rounded : Icons.error_outline_rounded,
              size: 32,
              color: good ? scheme.onPrimaryContainer : scheme.onErrorContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                good
                    ? l10n.reminderCheckAllGood
                    : l10n.reminderCheckIssues(issues),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: good
                      ? scheme.onPrimaryContainer
                      : scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _State { ok, bad, tip }

class _Row extends StatelessWidget {
  const _Row({
    required this.state,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final _State state;
  final IconData icon;
  final String title;
  final String subtitle;
  final (String, Future<void> Function())? action;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final action = this.action;
    return ListTile(
      leading: Icon(
        icon,
        color: switch (state) {
          _State.ok => scheme.primary,
          _State.bad => scheme.error,
          _State.tip => scheme.onSurfaceVariant,
        },
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: action != null
          ? FilledButton.tonal(onPressed: action.$2, child: Text(action.$1))
          : state == _State.ok
          ? Icon(Icons.check_rounded, color: scheme.primary)
          : null,
    );
  }
}
