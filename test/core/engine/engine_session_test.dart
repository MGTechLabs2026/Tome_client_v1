import 'package:build_engine/technique_plugin.dart' show TechniqueEvolved;
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/engine_session.dart';

void main() {
  test('bootstraps a PluginContext with every plugin this client needs initialized', () {
    final session = EngineSession(1);

    expect(session.context.entities, isNotNull);
    expect(session.context.tome, isNotNull);
    // Item content is loaded once ItemPlugin.initialize has run.
    expect(session.context.content.find('knife'), isNotNull);
  });

  test('accumulates technique lineage from TechniqueEvolved events', () {
    final session = EngineSession(2);

    session.context.events.publish(
      const TechniqueEvolved(fromId: 'basic_punch', toId: 'light_punch'),
    );

    expect(session.lineage['light_punch'], 'basic_punch');
  });
}
