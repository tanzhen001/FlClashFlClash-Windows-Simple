import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/windows_dashboard.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _Setup extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    requests.add(running);
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(null),
        setupActionProvider.overrideWith(_Setup.new),
        suspendProvider.overrideWithValue(false),
      ],
    );
    container.listen(totalTrafficProvider, (_, _) {});
    container.listen(trafficsProvider, (_, _) {});
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(980, 720),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: DashboardView(platform: SupportPlatform.Windows),
        ),
      ),
    );
    await tester.pump();
  }

  Finder toggle() => find.byKey(const ValueKey('windows-connection-toggle'));

  test('Windows has four primary destinations and retains diagnostics', () {
    final items = navigation.getItems(
      hasProxies: true,
      openLogs: true,
      platform: SupportPlatform.Windows,
    );
    expect(
      items
          .where((item) => item.modes.contains(NavigationItemMode.desktop))
          .map((item) => item.label),
      [
        PageLabel.dashboard,
        PageLabel.proxies,
        PageLabel.profiles,
        PageLabel.tools,
      ],
    );
    expect(
      items.singleWhere((item) => item.label == PageLabel.connections).modes,
      contains(NavigationItemMode.moreFull),
    );
    expect(
      items.singleWhere((item) => item.label == PageLabel.resources).modes,
      isEmpty,
    );
    expect(
      items.singleWhere((item) => item.label == PageLabel.logs).modes,
      contains(NavigationItemMode.more),
    );
  });

  testWidgets('an empty client disables connection and offers profile import', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.byType(WindowsDashboardView), findsOneWidget);
    expect(tester.widget<CommonSwitch>(toggle()).onChanged, isNull);
    expect(find.text('Add profile'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the connection control delegates start and stop', (
    tester,
  ) async {
    container
        .read(profilesProvider.notifier)
        .put(const Profile(id: 1, autoUpdateDuration: Duration.zero));
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await pumpDashboard(tester);

    await tester.tap(toggle());
    await tester.pump();
    expect(container.read(isStartProvider), isTrue);

    await tester.tap(toggle());
    await tester.pump();
    expect(container.read(isStartProvider), isFalse);
    expect((container.read(setupActionProvider.notifier) as _Setup).requests, [
      true,
      false,
    ]);
  });

  testWidgets('connecting clears on failure and allows another attempt', (
    tester,
  ) async {
    container
        .read(profilesProvider.notifier)
        .put(const Profile(id: 1, autoUpdateDuration: Duration.zero));
    container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    await pumpDashboard(tester);
    expect(tester.widget<CommonSwitch>(toggle()).onChanged, isNull);

    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await tester.pump();
    expect(tester.widget<CommonSwitch>(toggle()).onChanged, isNotNull);
    expect(
      find.descendant(of: toggle(), matching: find.byType(CommonCircleLoading)),
      findsNothing,
    );
  });

  testWidgets('node selection precedes profiles and traffic uses real values', (
    tester,
  ) async {
    container.read(totalTrafficProvider.notifier).value = const Traffic(
      up: 1024,
      down: 2048,
    );
    container.read(runTimeProvider.notifier).value = 1;
    await pumpDashboard(tester, size: const Size(380, 700));
    final total = tester.widget<Text>(
      find.byKey(const ValueKey('windows-traffic-total')),
    );
    expect(total.data, contains('1'));
    expect(total.data, contains('2'));
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('windows-node-selection')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('windows-profile-selection')))
            .dy,
      ),
    );
    expect(find.byKey(const ValueKey('windows-reset-traffic')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode controls delegate global and direct changes', (
    tester,
  ) async {
    await pumpDashboard(tester, size: const Size(380, 700));
    await tester.tap(find.byKey(const ValueKey('windows-mode-global')));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).mode, Mode.global);
    await tester.tap(find.byKey(const ValueKey('windows-mode-direct')));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).mode, Mode.direct);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short window with larger text scrolls without overflowing', (
    tester,
  ) async {
    await pumpDashboard(tester, size: const Size(540, 480), textScale: 1.4);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -700),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
