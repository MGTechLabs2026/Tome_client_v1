import 'package:build_engine/build_engine.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;

  setUp(() {
    session = EngineSession(1);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session);
    tomeAdapter.createInitialTome();
  });

  test('createInitialTome produces a 3x3 grid, all empty', () {
    final cells = tomeAdapter.inspect();
    expect(cells.length, 9);
    expect(cells.every((c) => c.isEmpty), isTrue);
    expect(tomeAdapter.width, 3);
    expect(tomeAdapter.height, 3);
  });

  test('insertItem places an occupant at the given slot', () {
    tomeAdapter.insertItem('knife', '0,0');

    final cell = tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0');
    expect(cell.isEmpty, isFalse);
    expect(cell.occupant!.contentId, 'knife');
  });

  test('move relocates an occupant', () {
    tomeAdapter.insertItem('knife', '0,0');
    tomeAdapter.move('0,0', '1,1');

    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0').isEmpty, isTrue);
    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '1,1').isEmpty, isFalse);
  });

  test('expandGrid grows the grid and preserves existing placements', () {
    tomeAdapter.insertItem('knife', '0,0');
    tomeAdapter.expandGrid();

    expect(tomeAdapter.width, 4);
    expect(tomeAdapter.height, 3);
    expect(tomeAdapter.inspect().length, 12);
    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0').occupant!.contentId, 'knife');
  });

  test('grantStartingKit hangs the chosen style\'s two-item kit, both usable', () {
    // A fresh session so the style is chosen before the kit is granted.
    final s = EngineSession(7);
    final character = CharacterAdapter(s)..createCharacter('Kit Fighter');
    character.chooseStyle(MartialStyles.fencing); // -> rapier + cloth
    final adapter = TomeAdapter(s)
      ..createInitialTome()
      ..grantStartingKit();

    final cells = adapter.inspect();
    expect(cells.firstWhere((c) => c.slotId == '1,1').occupant!.contentId,
        'rapier');
    expect(cells.firstWhere((c) => c.slotId == '1,2').occupant!.contentId,
        'cloth');
    expect(cells.where((c) => !c.isEmpty), hasLength(2));
  });

  test('grantStartingKit falls back to knife + cloth when no style was chosen',
      () {
    tomeAdapter.grantStartingKit();

    final cells = tomeAdapter.inspect();
    expect(cells.firstWhere((c) => c.slotId == '1,1').occupant!.contentId,
        'knife');
    expect(cells.firstWhere((c) => c.slotId == '1,2').occupant!.contentId,
        'cloth');
  });

  test('expandGrid destroys the old grid\'s placeholder entities (no leak)', () {
    tomeAdapter.insertItem('knife', '0,0');
    final oldTome = session.context.tome.tomeOf(session.character)!;
    final oldPlaceholder = oldTome.container.itemAt(const SlotId('0,0'))!;
    expect(session.context.entities.isAlive(oldPlaceholder), isTrue);

    tomeAdapter.expandGrid();

    expect(session.context.entities.isAlive(oldPlaceholder), isFalse);
    expect(session.context.components.get<BuildComponentRef>(oldPlaceholder), isNull);
  });
}
