import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/test_app.dart';
import '../test/helpers/app_paths.dart';
import '../test/helpers/preferences.dart';
import '../test/helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = Profile(
    id: 1,
    label: '我的订阅',
    autoUpdateDuration: Duration.zero,
  );

  late Directory temporary;
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('flclash-preview-');
    await useAppPaths(temporary);
    await mockPreferences();
    final bytes = await File('C:/Windows/Fonts/msyh.ttc').readAsBytes();
    await (FontLoader(
      'PreviewFont',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  tearDownAll(() => temporary.deleteSync(recursive: true));

  for (final (name, size, brightness) in [
    ('desktop-light', const Size(980, 820), Brightness.light),
    ('compact-dark', const Size(380, 700), Brightness.dark),
    ('compact-light', const Size(380, 700), Brightness.light),
  ]) {
    testWidgets('render $name', (tester) async {
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles(const [profile])),
          currentProfileProvider.overrideWithValue(profile),
          suspendProvider.overrideWithValue(false),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(themeSettingProvider.notifier)
          .update((state) => state.copyWith(fontFamily: 'PreviewFont'));
      navigationPort = navigation;
      addTearDown(() => navigationPort = null);
      container.read(viewSizeProvider.notifier).value = size;
      container.read(runTimeProvider.notifier).value = 1000;
      container.read(totalTrafficProvider.notifier).value = const Traffic(
        up: 55400,
        down: 127400,
      );
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 1200, down: 3400));
      container.read(groupsProvider.notifier).value = const [
        Group(
          name: '日本节点',
          type: GroupType.Selector,
          now: '日本 SSR',
          hidden: false,
          all: [Proxy(name: 'Japan SSR', type: 'ssr')],
        ),
      ];
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, brightness),
              child: RepaintBoundary(key: boundaryKey, child: const HomePage()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('build/ui-preview')
          ..createSync(recursive: true);
        await File(
          '${output.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
