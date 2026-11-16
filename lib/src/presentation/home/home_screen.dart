import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/native_all_util.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../core/notifications/reminder_service.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../lists/lists_tab.dart';
import '../tasks/task_editor_sheet.dart';
import '../today/today_tab.dart';
import '../upcoming/upcoming_tab.dart';

@RoutePage()
class HomeScreen extends StatefulLoggableWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  final _reminders = getIt<ReminderService>();

  @override
  void initState() {
    super.initState();
    NativeAllUtil.instance.preloadSlots();
    WidgetsBinding.instance.addObserver(this);
    _reminders.openTaskRequest.addListener(_openRequestedTask);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestedTask());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminders.openTaskRequest.removeListener(_openRequestedTask);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getIt<DayClock>().refresh();
    }
  }

  /// Notification tapped → open that task
  void _openRequestedTask() {
    final id = _reminders.openTaskRequest.value;
    if (id == null || !mounted) {
      return;
    }
    _reminders.openTaskRequest.value = null;
    unawaited(TaskEditorSheet.show(context, id));
  }

  List<Widget> _actions(BuildContext context) => [
    IconButton(
      tooltip: context.l10n.search,
      icon: const Icon(Icons.search_rounded),
      onPressed: () => context.pushRoute(const SearchRoute()),
    ),
    IconButton(
      tooltip: context.l10n.setting,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.pushRoute(const SettingRoute()),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    final l10n = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayTab(actions: actions),
          UpcomingTab(actions: actions),
          ListsTab(actions: actions),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    selectedIcon: const Icon(Icons.wb_sunny_rounded),
                    label: l10n.today,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: const Icon(Icons.calendar_month_rounded),
                    label: l10n.upcoming,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.format_list_bulleted_rounded),
                    selectedIcon: const Icon(Icons.view_list_rounded),
                    label: l10n.lists,
                  ),
                ],
              ),
            ),
            if (adUnitsConfig.nativeBanner.isEnable) _buildAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildAd() {
    return AutoReloadNativeAd(
      adConfig: adUnitsConfig.nativeBanner,
      expandedAdConfig: adUnitsConfig.nativeBannerExpand,
      enableAutoReload: true,
    );
  }
}
