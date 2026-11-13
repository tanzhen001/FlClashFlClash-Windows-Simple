import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _DeniedTunSetup extends SetupAction {
  @override
  Future<AuthorizeCode> authorizeCore() async => AuthorizeCode.error;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Core core;
  late ProviderContainer container;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    registerFallbackValue(
      defaultClashConfig.toUpdateParams(
        authentication: const [],
        skipCertVerify: false,
      ),
    );
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'GLOBAL', proxyName: 'SSR'),
    );
  });

  setUp(() {
    core = _Core();
    when(() => core.updateConfig(any())).thenAnswer((_) async => '');
    when(() => core.closeConnections()).thenAnswer((_) async => true);
    when(() => core.changeProxy(any())).thenAnswer(
      (_) async => const ChangeProxyResult(changed: true, message: ''),
    );
    when(() => core.resetTraffic()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(
              id: 1,
              autoUpdateDuration: Duration.zero,
              currentGroupName: 'Manual',
            ),
          ]),
        ),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
      ],
    );
    container.listen(trafficsProvider, (_, _) {});
    container.listen(totalTrafficProvider, (_, _) {});
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(runTimeProvider.notifier).value = 1;
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  test(
    'global selects a proxy instead of the implicit DIRECT default',
    () async {
      container.read(groupsProvider.notifier).value = const [
        Group(
          name: 'GLOBAL',
          type: GroupType.Selector,
          now: 'DIRECT',
          all: [
            Proxy(name: 'DIRECT', type: 'Direct'),
            Proxy(name: 'Manual', type: 'Selector'),
            Proxy(name: 'SSR', type: 'ShadowsocksR'),
          ],
        ),
      ];
      await container
          .read(setupActionProvider.notifier)
          .changeMode(Mode.global);
      final selection =
          verify(() => core.changeProxy(captureAny())).captured.single
              as ChangeProxyParams;
      expect(selection.groupName, 'GLOBAL');
      expect(selection.proxyName, 'Manual');
      expect(
        container.read(currentProfileProvider)?.selectedMap['GLOBAL'],
        'Manual',
      );
      final params =
          verify(() => core.updateConfig(captureAny())).captured.single
              as UpdateParams;
      expect(params.mode, Mode.global);
      verify(() => core.closeConnections()).called(1);
    },
  );

  test('an explicitly saved global selection is preserved', () async {
    container
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap('GLOBAL', 'DIRECT');
    container.read(groupsProvider.notifier).value = const [
      Group(
        name: 'GLOBAL',
        type: GroupType.Selector,
        all: [
          Proxy(name: 'DIRECT', type: 'Direct'),
          Proxy(name: 'SSR', type: 'ShadowsocksR'),
        ],
      ),
    ];
    await container.read(setupActionProvider.notifier).changeMode(Mode.global);
    verifyNever(() => core.changeProxy(any()));
    expect(
      container.read(currentProfileProvider)?.selectedMap['GLOBAL'],
      'DIRECT',
    );
  });

  test(
    'direct mode is sent immediately and existing sockets are closed',
    () async {
      await container
          .read(setupActionProvider.notifier)
          .changeMode(Mode.direct);
      final params =
          verify(() => core.updateConfig(captureAny())).captured.single
              as UpdateParams;
      expect(params.mode, Mode.direct);
      verify(() => core.closeConnections()).called(1);
    },
  );

  test('a mode change preserves TUN authorization and never enables a denied TUN', () async {
    container.dispose();
    container = ProviderContainer(overrides: [
      coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      setupActionProvider.overrideWith(_DeniedTunSetup.new),
      profilesProvider.overrideWith(TestProfiles.new),
    ]);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(patchClashConfigProvider.notifier).update((state) => state.copyWith(tun: state.tun.copyWith(enable: true)));
    await container.read(setupActionProvider.notifier).changeMode(Mode.direct);
    final params = verify(() => core.updateConfig(captureAny())).captured.single as UpdateParams;
    expect(params.mode, Mode.direct);
    expect(params.tun.enable, isFalse);
  });

  test('a failed mode update restores the prior selection', () async {
    when(() => core.updateConfig(any())).thenAnswer((_) async => 'rejected');
    await expectLater(
      container.read(setupActionProvider.notifier).changeMode(Mode.direct),
      throwsA(isA<MessageException>()),
    );
    expect(container.read(patchClashConfigProvider).mode, Mode.rule);
    verifyNever(() => core.closeConnections());
  });

  test('rapid mode requests converge on the newest mode', () async {
    final action = container.read(setupActionProvider.notifier);
    final first = action.changeMode(Mode.global);
    final last = action.changeMode(Mode.direct);
    await Future.wait([first, last]);
    expect(container.read(patchClashConfigProvider).mode, Mode.direct);
    final calls = verify(
      () => core.updateConfig(captureAny()),
    ).captured.cast<UpdateParams>();
    expect(calls.last.mode, Mode.direct);
  });

  test(
    'reset clears both counters and discards an older in-flight sample',
    () async {
      final traffic = Completer<Traffic>();
      final total = Completer<Traffic>();
      when(() => core.getTraffic(any())).thenAnswer((_) => traffic.future);
      when(() => core.getTotalTraffic(any())).thenAnswer((_) => total.future);
      final action = container.read(commonActionProvider.notifier);
      container.read(totalTrafficProvider.notifier).value = const Traffic(
        up: 1000,
        down: 2000,
      );
      final updating = action.updateTraffic();
      await action.resetTrafficStatistics();
      traffic.complete(const Traffic(up: 10, down: 20));
      total.complete(const Traffic(up: 3000, down: 4000));
      await updating;
      expect(container.read(totalTrafficProvider), const Traffic());
      expect(container.read(trafficsProvider).list, isEmpty);
      verify(() => core.resetTraffic()).called(1);
    },
  );

  test('a failed reset preserves the displayed totals', () async {
    when(() => core.resetTraffic()).thenThrow(StateError('disconnected'));
    container.read(totalTrafficProvider.notifier).value = const Traffic(
      up: 100,
      down: 200,
    );
    await expectLater(
      container.read(commonActionProvider.notifier).resetTrafficStatistics(),
      throwsStateError,
    );
    expect(
      container.read(totalTrafficProvider),
      const Traffic(up: 100, down: 200),
    );
  });
}
