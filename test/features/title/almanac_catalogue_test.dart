// Guards the ALMANAC's hand-maintained id catalogue against engine
// drift: every id it lists must still resolve in build_engine, and the
// style list must match the engine's MartialStyles set exactly (a
// small, closed set — a rename like taiChi/taichi must not slip
// through). Items/techniques are only checked for resolution, since the
// Almanac deliberately lists a curated subset (evolved techniques are
// left as in-run surprises).
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/title/almanac_screen.dart';

void main() {
  late EngineSession session;
  setUp(() => session = EngineSession(1));

  test('every Almanac style id is a real MartialStyles id, and all styles '
      'are listed', () {
    const engineStyles = {
      MartialStyles.polearming,
      MartialStyles.wrestling,
      MartialStyles.fencing,
      MartialStyles.shaolin,
      MartialStyles.taiChi,
      MartialStyles.kunlun,
    };
    expect(almanacStyles.map((e) => e.$1).toSet(), engineStyles);
  });

  test('every Almanac item id resolves in the engine', () {
    for (final (id, _) in almanacItems) {
      expect(() => itemDefinition(id, session.context), returnsNormally,
          reason: 'unknown item id "$id" in the Almanac catalogue');
    }
  });

  test('every Almanac technique id resolves in the engine', () {
    for (final (id, _) in almanacTechniques) {
      expect(() => techniqueDefinition(id, session.context), returnsNormally,
          reason: 'unknown technique id "$id" in the Almanac catalogue');
    }
  });
}
