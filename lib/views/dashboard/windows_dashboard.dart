import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'layout.dart';
import 'style.dart';
import 'widgets/card.dart';
import 'widgets/widgets.dart';

class WindowsDashboardView extends StatelessWidget {
  const WindowsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: appName,
      backgroundColor: DashboardColors.of(context).page,
      body: Builder(
        builder: (context) => DashboardDensityScope(
          density: DashboardDensity.mobile,
          scale: MediaQuery.textScalerOf(context).scale(1),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              context.contentTopPadding,
              20,
              24 + context.bottomInset,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    const _ConnectionCard(),
                    const OutboundModeCard(),
                    SizedBox(
                      height: 72 * MediaQuery.textScalerOf(context).scale(1),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: [
                          Expanded(
                            child: NetworkTakeoverTile(
                              TakeoverSwitch.systemProxy,
                            ),
                          ),
                          Expanded(
                            child: NetworkTakeoverTile(TakeoverSwitch.tun),
                          ),
                        ],
                      ),
                    ),
                    const ProfilesCard(),
                    const ProxyGroupsSummaryCard(),
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

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.appLocalizations;
    final running = ref.watch(isStartProvider);
    final suspended = running && ref.watch(suspendProvider);
    final connecting = ref.watch(coreStatusProvider) == CoreStatus.connecting;
    final hasProfiles = ref.watch(
      profilesProvider.select((profiles) => profiles.isNotEmpty),
    );
    final profile = ref.watch(currentProfileProvider);
    final status = connecting
        ? strings.connecting
        : suspended
        ? strings.suspended
        : running
        ? strings.running
        : strings.notRunning;
    final action = running ? strings.stop : strings.start;
    final colors = context.colorScheme;
    return DashboardCard(
      semanticLabel: strings.status,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Row(
        spacing: 20,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  status,
                  style: AppTextStyle.title2.of(context, emphasized: true),
                ),
                Text(
                  profile?.realLabel ?? strings.addProfile,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: colors.onSurfaceVariant),
                ),
                if (!hasProfiles)
                  TextButton(
                    onPressed: () => ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.profiles),
                    child: Text(strings.addProfile),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SizedBox.square(
                dimension: 72,
                child: IconButton.filled(
                  key: const ValueKey('windows-connection-toggle'),
                  tooltip: action,
                  onPressed: hasProfiles && !connecting
                      ? () => ref
                            .read(commonActionProvider.notifier)
                            .toggleRunning()
                      : null,
                  style: FilledButton.styleFrom(shape: AppShape.full),
                  icon: connecting
                      ? const CommonCircleLoading()
                      : GlyphIcon(
                          AppGlyphs.playPause(running ? 1 : 0),
                          size: 32,
                          fill: 1,
                        ),
                ),
              ),
              Text(action, style: AppTextStyle.footnote.of(context)),
            ],
          ),
        ],
      ),
    );
  }
}
