import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'layout.dart';
import 'style.dart';
import 'widgets/card.dart';
import 'widgets/profile_detail.dart';
import 'widgets/proxy_groups.dart';

class WindowsDashboardView extends StatelessWidget {
  const WindowsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      titleWidget: Center(
        child: Text(
          appName,
          style: AppTextStyle.title3.of(context, emphasized: true),
        ),
      ),
      backgroundColor: DashboardColors.of(context).page,
      body: Builder(
        builder: (context) => DashboardDensityScope(
          density: DashboardDensity.mobile,
          scale: MediaQuery.textScalerOf(context).scale(1),
          child: SingleChildScrollView(
            key: const ValueKey('windows-dashboard-scroll'),
            padding: EdgeInsets.fromLTRB(
              20,
              context.contentTopPadding,
              20,
              20 + context.bottomInset,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: [
                    DashboardCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _ConnectionStatus(),
                          const _TrafficStatistics(),
                          const Divider(height: 24),
                          const _ModeControl(),
                          const Divider(height: 24),
                          const _NodeSelection(),
                          const Divider(height: 1),
                          const _ProfileSelection(),
                          const Divider(height: 1),
                          const _TakeoverControls(),
                        ],
                      ),
                    ),
                    DashboardCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _SettingsRow(
                            title: context.appLocalizations.settings,
                            glyph: AppGlyphs.settings,
                            onTap: () => showSheet<void>(
                              context: context,
                              builder: (_) => const ToolsView(),
                            ),
                          ),
                          const Divider(height: 1),
                          _SettingsRow(
                            title: context.appLocalizations.core,
                            glyph: AppGlyphs.cpu,
                            onTap: () => showSheet<void>(
                              context: context,
                              builder: (_) => const GeneralView(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.appLocalizations;
    final running = ref.watch(isStartProvider);
    final suspended = running && ref.watch(suspendProvider);
    final connecting = ref.watch(coreStatusProvider) == CoreStatus.connecting;
    final hasProfiles = ref.watch(
      profilesProvider.select((profiles) => profiles.isNotEmpty),
    );
    final status = connecting
        ? strings.connecting
        : suspended
        ? strings.suspended
        : running
        ? strings.running
        : strings.notRunning;
    final color = running && !suspended
        ? context.colorScheme.success
        : context.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(status, style: AppTextStyle.subheadline.of(context)),
        ),
        if (connecting)
          const SizedBox.square(dimension: 20, child: CommonCircleLoading()),
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.colorScheme.copyWith(
              primary: context.colorScheme.success,
            ),
          ),
          child: CommonSwitch(
            key: const ValueKey('windows-connection-toggle'),
            semanticLabel: running ? strings.stop : strings.start,
            value: running,
            onChanged: hasProfiles && !connecting
                ? (_) => ref.read(commonActionProvider.notifier).toggleRunning()
                : null,
          ),
        ),
      ],
    );
  }
}

class _TrafficStatistics extends ConsumerStatefulWidget {
  const _TrafficStatistics();

  @override
  ConsumerState<_TrafficStatistics> createState() => _TrafficStatisticsState();
}

class _TrafficStatisticsState extends ConsumerState<_TrafficStatistics> {
  bool _resetting = false;

  Future<void> _reset() async {
    if (_resetting) return;
    final strings = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: strings.resetTrafficStatistics,
      message: TextSpan(text: strings.resetTrafficStatisticsTip),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await globalState.safeRun(
        () => ref.read(commonActionProvider.notifier).resetTrafficStatistics(),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(isStartProvider);
    final total = ref.watch(totalTrafficProvider);
    final latest = ref.watch(trafficsProvider).list.safeLast(const Traffic());
    final speed = running ? latest : const Traffic();
    final style = AppTextStyle.caption1.of(context).toTabular;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                '↑ ${dashboardTraffic(total.up)}  ↓ ${dashboardTraffic(total.down)}',
                key: const ValueKey('windows-traffic-total'),
                style: style,
              ),
              Text(
                '↑ ${dashboardTraffic(speed.up)}/s  ↓ ${dashboardTraffic(speed.down)}/s',
                key: const ValueKey('windows-traffic-speed'),
                style: style,
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('windows-reset-traffic'),
          tooltip: context.appLocalizations.resetTrafficStatistics,
          onPressed: _resetting ? null : _reset,
          icon: _resetting
              ? const CommonCircleLoading()
              : const GlyphIcon(AppGlyphs.reset, size: 18),
        ),
      ],
    );
  }
}

class _ModeControl extends ConsumerStatefulWidget {
  const _ModeControl();

  @override
  ConsumerState<_ModeControl> createState() => _ModeControlState();
}

class _ModeControlState extends ConsumerState<_ModeControl> {
  bool _busy = false;

  Future<void> _select(Mode mode) async {
    if (_busy || ref.read(patchClashConfigProvider).mode == mode) return;
    setState(() => _busy = true);
    try {
      await globalState.safeRun(
        () => ref.read(setupActionProvider.notifier).changeMode(mode),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    return DashboardConnectedGroup(
      children: [
        for (final (index, item) in Mode.values.indexed)
          Expanded(
            child: DashboardConnectedButton(
              key: ValueKey('windows-mode-${item.name}'),
              selected: item == mode,
              first: index == 0,
              last: index == Mode.values.length - 1,
              outer: AppCorner.full,
              inner: AppCorner.full,
              background: DashboardColors.of(context).tone,
              semanticLabel: item.label,
              onTap: () {
                if (!_busy) _select(item);
              },
              builder: (foreground) => SizedBox(
                height: 38,
                child: Center(
                  child: Text(
                    item.label,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: foreground),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NodeSelection extends ConsumerWidget {
  const _NodeSelection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final groups = ref.watch(groupsProvider);
    final currentGroup = ref.watch(
      currentProfileProvider.select((profile) => profile?.currentGroupName),
    );
    final group = mode == Mode.global
        ? groups.getGroup('GLOBAL')
        : groups.getGroup(currentGroup == 'GLOBAL' ? '' : currentGroup ?? '') ??
              groups
                  .where(
                    (group) => group.name != 'GLOBAL' && group.hidden != true,
                  )
                  .firstOrNull;
    final selected = group == null
        ? null
        : ref.watch(selectedProxyNameProvider(group.name));
    final subtitle = mode == Mode.direct
        ? context.appLocalizations.direct
        : group == null
        ? context.appLocalizations.proxyGroupsAfterStart
        : '${group.name} → ${selected ?? group.realNow}';
    return _DetailRow(
      key: const ValueKey('windows-node-selection'),
      title: context.appLocalizations.nodeSelection,
      subtitle: subtitle,
      onTap: mode != Mode.direct && group != null
          ? () => showProxiesSheet(context, groupName: group.name)
          : null,
    );
  }
}

class _ProfileSelection extends ConsumerWidget {
  const _ProfileSelection();

  Future<void> _importClipboard(WidgetRef ref) async {
    await globalState.safeRun(() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final links = (data?.text ?? '')
          .split(RegExp(r'\s+'))
          .where((link) => link.isNotEmpty)
          .toList();
      if (links.isEmpty ||
          links.any((link) => !link.isShareLink && !link.isUrl)) {
        throw MessageException(currentAppLocalizations.invalidLinkTip);
      }
      final action = ref.read(profilesActionProvider.notifier);
      if (links.length == 1) {
        await action.addProfileFromLink(links.single);
      } else {
        await action.addProfilesFromLinks(links);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return _DetailRow(
      key: const ValueKey('windows-profile-selection'),
      title: context.appLocalizations.profile,
      subtitle: profile?.realLabel ?? context.appLocalizations.addProfile,
      onTap: () => showProfilesSheet(context),
      trailing: IconButton(
        tooltip: context.appLocalizations.clipboardImport,
        onPressed: () => _importClipboard(ref),
        icon: const GlyphIcon(AppGlyphs.add),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: AppShape.sm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(title, style: AppTextStyle.subheadline.of(context)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.primary),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null)
              const GlyphIcon(AppGlyphs.chevronForward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TakeoverControls extends ConsumerWidget {
  const _TakeoverControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );
    final tun = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: _TakeoverButton(
              label: context.appLocalizations.systemProxy,
              enabled: systemProxy,
              onTap: () => ref
                  .read(networkSettingProvider.notifier)
                  .update((state) => state.copyWith(systemProxy: !systemProxy)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TakeoverButton(
              label: 'TUN',
              enabled: tun,
              onTap: () => ref
                  .read(patchClashConfigProvider.notifier)
                  .update(
                    (state) =>
                        state.copyWith(tun: state.tun.copyWith(enable: !tun)),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeoverButton extends StatelessWidget {
  const _TakeoverButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 6,
      children: [
        GlyphIcon(enabled ? AppGlyphs.check : AppGlyphs.removeCircle, size: 16),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption1.of(context),
          ),
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.glyph,
    required this.onTap,
  });
  final String title;
  final Glyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: AppShape.md,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      child: Row(
        spacing: 16,
        children: [
          GlyphIcon(glyph, size: 20),
          Expanded(
            child: Text(title, style: AppTextStyle.subheadline.of(context)),
          ),
          const GlyphIcon(AppGlyphs.chevronForward, size: 18),
        ],
      ),
    ),
  );
}
