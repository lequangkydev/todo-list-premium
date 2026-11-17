import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/native_all_util.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../core/focus/focus_service.dart';
import '../../core/widgets/launch_links.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../lists/lists_tab.dart';
import '../reminders/alarm_screen.dart';
import '../reminders/snooze_sheet.dart';
import '../tasks/quick_add_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    NativeAllUtil.instance.preloadSlots();
    WidgetsBinding.instance.addObserver(this);
    LaunchLinks.instance.pending.addListener(_openLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLink());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LaunchLinks.instance.pending.removeListener(_openLink);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getIt<DayClock>().refresh();
    }
  }

  /// Widget, Quick Settings tile, app shortcut or notification → go where it
  /// points
  void _openLink() {
    if (!mounted || LaunchLinks.instance.pending.value == null) {
      return;
    }
    final uri = LaunchLinks.instance.take()!;
    // Come back to Home from wherever the user was (sheets, settings…)
    final home = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == home || route.isFirst);
    setState(() => _tab = 0);
    final id = uri.queryParameters['id'];
    switch (uri.host) {
      case 'quickadd':
        unawaited(QuickAddSheet.show(context));
      case 'task' when id != null:
        unawaited(TaskEditorSheet.show(context, id));
      case 'alarm' when id != null:
        unawaited(AlarmScreen.show(context, id));
      case 'snooze' when id != null:
        unawaited(SnoozeSheet.show(context, id));
      case 'focus':
        unawaited(context.pushRoute(FocusRoute()));
      case 'upcoming':
        setState(() => _tab = 1);
      case 'plan':
        final day = DateTime.tryParse(uri.queryParameters['day'] ?? '');
        unawaited(context.pushRoute(DayPlanRoute(day: day)));
      case 'stats':
        unawaited(context.pushRoute(const StatsRoute()));
    }
  }

  List<Widget> _actions(BuildContext context) => [
    ValueListenableBuilder(
      valueListenable: getIt<FocusService>().state,
      builder: (context, focus, _) => IconButton(
        tooltip: context.l10n.focus,
        // Filled while a focus block or break is going
        icon: Icon(focus.active ? Icons.timer_rounded : Icons.timer_outlined),
        color: focus.active ? context.colorScheme.primary : null,
        onPressed: () => context.pushRoute(FocusRoute()),
      ),
    ),
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
      body: _FadeThroughStack(
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
                onDestinationSelected: (index) {
                  if (index != _tab) {
                    AppHaptics.selection();
                  }
                  setState(() => _tab = index);
                },
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

/// [IndexedStack] that fades the newly selected tab in with a slight scale
/// (Material fade-through). Every tab keeps its state and scroll position.
class _FadeThroughStack extends StatefulWidget {
  const _FadeThroughStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<_FadeThroughStack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.25, 1, curve: Curves.easeOut),
  );
  late final _scale = Tween<double>(
    begin: .96,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));

  static const _still = AlwaysStoppedAnimation<double>(1);

  @override
  void didUpdateWidget(covariant _FadeThroughStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && AppMotion.enabled(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          // Same wrappers for every tab so switching never rebuilds a tab
          FadeTransition(
            opacity: i == widget.index ? _fade : _still,
            child: ScaleTransition(
              scale: i == widget.index ? _scale : _still,
              child: widget.children[i],
            ),
          ),
      ],
    );
  }
}
