// test/tome_visual_capture_test.dart
//
// Dev harness: renders the real app (real fonts, real engine data) at
// the two shipped form factors and writes PNGs to .impeccable/review/
// for the batched inspection round. Not a behavioural test.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/models/grid_cell_view.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/tome/hall/hall_theme.dart';
import 'package:tome_client/features/tome/hall/mount.dart';

Future<void> _loadFonts() async {
  for (final family in const ['Cinzel', 'Archivo', 'SplineSansMono']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _capture(WidgetTester tester, Key key, String path) async {
  final boundary =
      tester.firstRenderObject(find.byKey(key)) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

Future<void> _run(WidgetTester tester, Size size, String path) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    return tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: TomeApp(runBloc: RunBloc(), session: EngineSession(4242)),
    ),
  );
  await tester.pump(const Duration(seconds: 1));

  await tester.enterText(find.byType(TextField), 'Mireille Vasquez');
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byType(InkWell).first);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));

  await _capture(tester, key, path);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('capture Tome — desktop', (tester) async {
    await _run(tester, const Size(1280, 832), '.impeccable/review/desktop.png');
  });

  testWidgets('capture Tome — mobile', (tester) async {
    await _run(tester, const Size(402, 874), '.impeccable/review/mobile.png');
  });

  // Synthetic mount states — a fresh run only ever shows one, so this
  // renders all four side by side from MountView for DESIGN.md.
  testWidgets('capture states — mounts', (tester) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(880, 520));
    tester.view.physicalSize = const Size(880, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      return tester.binding.setSurfaceSize(null);
    });

    MountData md(String id, MountState s,
            {int lvl = 0, double prog = 0, int cls = 1, int? maxCls, bool maxed = false}) =>
        MountData(
          contentId: id,
          displayName: id.replaceAll('_', ' '),
          kind: GridComponentKind.item,
          state: s,
          masteryLevel: lvl,
          masteryProgress01: prog,
          itemClass: cls,
          maxClass: maxCls,
          maxed: maxed,
          address: '1,1',
          annotation: 'cls ${'I' * cls}',
        );

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tomeTheme(),
          home: Builder(builder: (context) {
            final hall = context.hall;
            return Scaffold(
              backgroundColor: hall.lacquerDeep,
              body: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOUNT STATES', style: hall.heading.copyWith(fontSize: 13)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: Row(
                        children: [
                          for (final m in [
                            md('locked_form', MountState.locked, prog: 0.4),
                            md('usable_form', MountState.usable, lvl: 1, prog: 0.6),
                            md('mastered_form', MountState.mastered,
                                lvl: 4, cls: 3, maxCls: 3, maxed: true),
                            md('hung_form', MountState.active, lvl: 2, prog: 0.3),
                          ])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: MountView(data: m, selected: m.state == MountState.active),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(tester, key, '.impeccable/review/states.png');
  });
}
