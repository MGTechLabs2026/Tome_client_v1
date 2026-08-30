// test/tome_visual_capture_test.dart
//
// Dev harness: renders the real app (real fonts, real engine data) at
// the two shipped form factors and writes PNGs to .impeccable/review/
// for the batched inspection round. Not a behavioural test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/run/run_bloc.dart';

Future<void> _loadFonts() async {
  for (final family in const ['Cinzel', 'Archivo', 'SplineSansMono']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _pump(WidgetTester tester, [int frames = 24]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 90));
  }
}

Future<void> _capture(WidgetTester tester, Key key, String path) async {
  final boundary = tester.firstRenderObject(find.byKey(key)) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
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
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: TomeApp(runBloc: RunBloc(), session: EngineSession(4242)),
    ),
  );
  await _pump(tester);
  await tester.enterText(find.byType(TextField), 'Mireille Vasquez');
  await _pump(tester, 4);
  await tester.tap(find.text('Continue'));
  await _pump(tester);
  await tester.tap(find.byType(InkWell).first);
  await _pump(tester);
  await _capture(tester, key, path);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('capture Tome — desktop', (tester) async {
    await _run(tester, const Size(1280, 832), '.impeccable/review/desktop.png');
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('capture Tome — mobile', (tester) async {
    await _run(tester, const Size(402, 874), '.impeccable/review/mobile.png');
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
