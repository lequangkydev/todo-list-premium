import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../module/remote_config/remote_config.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../core/backup/backup_service.dart';
import '../../core/notifications/reminder_health.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/notifications/reminder_settings.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/cubit/haptics_cubit.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/cubit/lunar_cubit.dart';
import '../../shared/cubit/smart_suggestions_cubit.dart';
import '../../shared/cubit/theme_mode_cubit.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/task_format.dart';
import '../../shared/widgets/dialog/rate_dialog.dart';
import '../backup/backup_labels.dart';

@RoutePage()
class SettingScreen extends StatefulLoggableWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with WidgetsBindingObserver {
  final _reminders = getIt<ReminderService>();
  final _settings = getIt<ReminderSettings>();
  bool isSharing = false;
  bool? _notificationsOn;
  bool? _exactOn;
  bool _batteryOptimized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system settings
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final notifications = await _reminders.notificationsEnabled();
    final exact = await _reminders.exactAlarmsAllowed();
    final device = await ReminderHealth.read();
    if (mounted) {
      setState(() {
        _notificationsOn = notifications;
        _exactOn = exact;
        _batteryOptimized = device.batteryOptimized;
      });
    }
  }

  /// Same count as the reminder check screen shows
  int get _reminderIssues => [
    _notificationsOn == false,
    _exactOn == false,
    _batteryOptimized,
  ].where((bad) => bad).length;

  Future<void> _pickEveningTime() async {
    final minutes = _settings.evening.value.minutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) {
      await _settings.setEvening(
        on: true,
        minutes: picked.hour * 60 + picked.minute,
      );
    }
  }

  Future<void> _pickDigestTime() async {
    final minutes = _settings.digest.value.minutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) {
      await _settings.setDigest(
        on: true,
        minutes: picked.hour * 60 + picked.minute,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch ');
    }
  }

  Future<void> shareApp(BuildContext context) async {
    if (isSharing) {
      return;
    }
    isSharing = true;
    try {
      final String appLink = Platform.isAndroid
          ? AppConstants.appAndroidUrl
          : AppConstants.appIOSUrl;

      MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        appLink,
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } finally {
      isSharing = false;
    }
  }

  Future<void> _fixNotifications() async {
    MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
    if (_notificationsOn == false) {
      await _reminders.requestNotifications();
      // Permanently denied → only the system settings page can turn it on
      if (!await _reminders.notificationsEnabled()) {
        await FlutterLocalNotificationsPlugin().openAppNotificationSettings();
      }
    }
    await _refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final language = context.watch<LanguageCubit>().state;
    final themeMode = context.watch<ThemeModeCubit>().state;
    final haptics = context.watch<HapticsCubit>().state;
    final smart = context.watch<SmartSuggestionsCubit>().state;
    context.watch<LunarCubit>();
    final lunar = getIt<LunarCubit>().showFor(language);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setting)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Group(
            title: l10n.reminders,
            children: [
              ListTile(
                leading: Icon(
                  _notificationsOn == false
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  color: _notificationsOn == false ? scheme.error : null,
                ),
                title: Text(l10n.notifications),
                subtitle: Text(
                  _notificationsOn == false
                      ? l10n.notificationsOffHint
                      : l10n.notificationsOnHint,
                ),
                trailing: _notificationsOn == false
                    ? FilledButton.tonal(
                        onPressed: _fixNotifications,
                        child: Text(l10n.turnOn),
                      )
                    : const Icon(Icons.check_rounded),
              ),
              const Divider(indent: 56),
              ValueListenableBuilder(
                valueListenable: _settings.digest,
                builder: (context, digest, _) => ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: Text(l10n.morningSummary),
                  subtitle: Text(
                    l10n.morningSummaryHint(
                      TaskFormat.time(context, digest.minutes),
                    ),
                  ),
                  onTap: _pickDigestTime,
                  trailing: Switch(
                    value: digest.on,
                    onChanged: (on) {
                      AppHaptics.selection();
                      _settings.setDigest(on: on);
                    },
                  ),
                ),
              ),
              const Divider(indent: 56),
              ValueListenableBuilder(
                valueListenable: _settings.evening,
                builder: (context, evening, _) => ListTile(
                  leading: const Icon(Icons.nights_stay_outlined),
                  title: Text(l10n.eveningNudge),
                  subtitle: Text(
                    l10n.eveningNudgeHint(
                      TaskFormat.time(context, evening.minutes),
                    ),
                  ),
                  onTap: _pickEveningTime,
                  trailing: Switch(
                    value: evening.on,
                    onChanged: (on) {
                      AppHaptics.selection();
                      _settings.setEvening(on: on);
                    },
                  ),
                ),
              ),
              const Divider(indent: 56),
              ValueListenableBuilder(
                valueListenable: _settings.weekly,
                builder: (context, weekly, _) => SwitchListTile(
                  secondary: const Icon(Icons.insights_rounded),
                  title: Text(l10n.weeklyRecap),
                  subtitle: Text(l10n.weeklyRecapHint),
                  value: weekly,
                  onChanged: (on) {
                    AppHaptics.selection();
                    _settings.setWeekly(on: on);
                  },
                ),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: Icon(
                  Icons.fact_check_outlined,
                  color: _reminderIssues > 0 ? scheme.error : null,
                ),
                title: Text(l10n.reminderCheck),
                subtitle: Text(
                  _reminderIssues > 0
                      ? l10n.reminderCheckIssues(_reminderIssues)
                      : l10n.reminderCheckHint,
                  style: _reminderIssues > 0
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await context.pushRoute(const ReminderCheckRoute());
                  await _refreshPermissions();
                },
              ),
            ],
          ),
          _Group(
            title: l10n.suggestion,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: Text(l10n.smartSuggestions),
                subtitle: Text(l10n.smartSuggestionsHint),
                value: smart,
                onChanged: (on) {
                  AppHaptics.selection();
                  context.read<SmartSuggestionsCubit>().update(on);
                },
              ),
            ],
          ),
          _Group(
            title: l10n.appearance,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l10n.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.themeDark),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) {
                    AppHaptics.selection();
                    context.read<ThemeModeCubit>().update(s.first);
                  },
                ),
              ),
              const Divider(indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: Text(l10n.haptics),
                subtitle: Text(l10n.hapticsHint),
                value: haptics,
                onChanged: (on) {
                  context.read<HapticsCubit>().update(on);
                  if (on) {
                    AppHaptics.selection();
                  }
                },
              ),
              const Divider(indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.lunarCalendar),
                subtitle: Text(l10n.lunarCalendarHint),
                value: lunar,
                onChanged: (on) {
                  AppHaptics.selection();
                  context.read<LunarCubit>().update(on);
                },
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: Text(l10n.language),
                subtitle: Text(language.languageName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushRoute(LanguageRoute()),
              ),
            ],
          ),
          _Group(
            title: l10n.dataGroup,
            children: [
              ValueListenableBuilder(
                valueListenable: getIt<BackupService>().lastBackup,
                builder: (context, last, _) => ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(l10n.backupTitle),
                  subtitle: Text(
                    last == null
                        ? l10n.backupNone
                        : l10n.backupLast(backupWhen(context, last)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.pushRoute(const BackupRoute()),
                ),
              ),
            ],
          ),
          _Group(
            title: l10n.about,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(l10n.privacyTitle),
                subtitle: Text(
                  '${l10n.privacyMessage}\n${l10n.privacyDiagnostics}',
                ),
                isThreeLine: true,
              ),
              const Divider(indent: 56),
              Builder(
                builder: (context) => ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text(l10n.share),
                  onTap: () => shareApp(context),
                ),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: Text(l10n.rateUs),
                onTap: () => showRatingDialog(fromSetting: true),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: Text(l10n.policy),
                onTap: () => _launchUrl(
                  RemoteConfigManager.instance.appConfig.urlPolicy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
