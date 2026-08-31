import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/codex_repository.dart';
import 'package:tome_client/core/persistence/game_store.dart';

void main() {
  test('starts empty', () {
    final c = CodexRepository(GameStore.memory());
    expect(c.snapshot.isEmpty, isTrue);
    expect(c.snapshot.total, 0);
  });

  test('discover records under the right kind and dedupes', () async {
    final c = CodexRepository(GameStore.memory());
    await c.discover(CodexKind.style, 'kunlun');
    await c.discover(CodexKind.style, 'kunlun');
    await c.discover(CodexKind.item, 'rapier');
    await c.discover(CodexKind.technique, 'basic_slash');

    expect(c.snapshot.styles, {'kunlun'});
    expect(c.snapshot.items, {'rapier'});
    expect(c.snapshot.techniques, {'basic_slash'});
    expect(c.snapshot.total, 3);
  });

  test('ignores empty ids', () async {
    final c = CodexRepository(GameStore.memory());
    await c.discover(CodexKind.style, '');
    expect(c.snapshot.isEmpty, isTrue);
  });

  test('persists through the store', () async {
    final store = GameStore.memory();
    await CodexRepository(store).discover(CodexKind.item, 'staff');
    expect(CodexRepository(store).snapshot.items, {'staff'});
  });
}
