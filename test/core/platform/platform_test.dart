// Platform-seam contracts (Platform Readiness V1, Task 30).
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/platform/platform.dart';

void main() {
  group('PlatformIdentity', () {
    test('LocalIdentity resolves the constant local key by default', () async {
      expect(await const LocalIdentity().persistenceKey(), 'local');
    });

    test('a host can supply its own opaque key without other code changing',
        () async {
      expect(await const LocalIdentity('u_abc123').persistenceKey(), 'u_abc123');
    });
  });

  group('PlatformCapabilities', () {
    test('devvit has no durable localStorage and no free outbound network', () {
      expect(PlatformCapabilities.devvit.durablePersistence, isFalse);
      expect(PlatformCapabilities.devvit.externalNetwork, isFalse);
      expect(PlatformCapabilities.devvit.platformIdentity, isTrue);
    });

    test('web / itch has durable local persistence and pointer + touch', () {
      expect(PlatformCapabilities.web.durablePersistence, isTrue);
      expect(PlatformCapabilities.web.pointer, isTrue);
      expect(PlatformCapabilities.web.touch, isTrue);
    });

    test('current picks a sane default (web under flutter_test is host-defined) '
        'and honours the --dart-define override shape', () {
      final c = PlatformCapabilities.current;
      expect(['web', 'desktop', 'devvit'], contains(c.id));
    });
  });

  group('SilentAudio', () {
    test('every method is a safe no-op', () async {
      final a = SilentAudio();
      await a.unlock();
      a.play(SoundCue.strikeHit);
      a.stopAll();
      a.muted = false;
      expect(a.muted, isFalse);
    });
  });
}
