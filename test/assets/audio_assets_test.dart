// test/assets/audio_assets_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/platform/game_audio.dart';

void main() {
  test('every SoundCue has a bundled asset file under 150KB total', () {
    final dir = Directory('assets/audio');
    expect(dir.existsSync(), isTrue, reason: 'run tools/gen_sfx.py');

    var total = 0;
    for (final cue in SoundCue.values) {
      final f = File('assets/audio/${cue.name}.ogg');
      expect(f.existsSync(), isTrue,
          reason: 'missing assets/audio/${cue.name}.ogg — run tools/gen_sfx.py '
              'with ffmpeg on PATH');
      final bytes = f.readAsBytesSync();
      expect(bytes.length, greaterThan(64), reason: '${cue.name} is empty');
      expect(String.fromCharCodes(bytes.take(4)), 'OggS',
          reason: '${cue.name}.ogg has a bad header');
      total += bytes.length;
    }
    expect(total, lessThan(150 * 1024));
  });

  test('pubspec declares assets/audio/', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/'));
  });
}
