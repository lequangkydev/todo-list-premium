part of '../permission_screen.dart';

class PermissionBody extends StatefulWidget {
  const PermissionBody({super.key, this.adController});

  final AdController? adController;

  @override
  State<PermissionBody> createState() => _PermissionContentState();
}

class _PermissionContentState extends State<PermissionBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _refresh();
  }

  final _reminders = getIt<ReminderService>();
  bool? _notificationsOn;

  Future<void> _refresh() async {
    final on = await _reminders.notificationsEnabled();
    if (mounted) {
      setState(() => _notificationsOn = on);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value || (_notificationsOn ?? false)) {
      return;
    }
    await _reminders.requestNotifications();
    if (!await _reminders.notificationsEnabled()) {
      // Denied before → only the system settings page can turn it on
      await PermissionUtil.instance.requestPermissionNotificationDefault(
        openSetting: true,
      );
    }
    await _refresh();
  }

  AdUnitConfig get _adConfig =>
      widget.adController?.adKey == 'native_permission_storage'
      ? adUnitsConfig.nativePermissionStorage
      : adUnitsConfig.nativePermission;

  Widget _buildAd() {
    return AutoReloadNativeAd.control(
      key: ValueKey(widget.adController?.adKey),
      controller: widget.adController,
      type: _adConfig.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final on = _notificationsOn ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: Column(
              children: [
                const SizedBox(height: AppSpace.xl),
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.xl + 4),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 56,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.permissionTitle,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  context.l10n.permissionMessage,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Card(
                  child: SwitchListTile(
                    value: on,
                    onChanged: _toggleNotifications,
                    secondary: const Icon(Icons.notifications_none_rounded),
                    title: Text(context.l10n.notifications),
                    subtitle: Text(
                      on
                          ? context.l10n.notificationsOnHint
                          : context.l10n.permissionNotificationsHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_adConfig.isBottomAd) _buildAd(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.md,
            AppSpace.xl,
            AppSpace.lg,
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              child: Text(
                on
                    ? context.l10n.continueText
                    : context.l10n.grantPermissionLater,
              ),
              onPressed: () {
                context.replaceRoute(const HomeRoute());
                SharedPreferencesManager.instance.markFirstPermissionAsShown();
              },
            ),
          ),
        ),
        // collapsibleBanner/large → neo đáy màn
        if (_adConfig.isBottomAd) _buildAd(),
      ],
    );
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      PermissionUtil.instance.checkAllPermissions();
      await _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
