import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/domain/models.dart';
import 'package:rive/rive.dart' as rive;

/// Validates the generated Rive animals against the real Rive runtime.
/// Needs the rive_native desktop library (`dart run rive_native:setup`);
/// skipped where it is not installed so CI without it still runs.
bool get _runtimeAvailable => [
  'build/rive_native/native/build/windows/bin/lib/debug/rive_native.dll',
  'build/rive_native/native/build/macosx/bin/debug_shared/librive_native.dylib',
  'build/rive_native/native/build/linux/bin/lib/debug_shared/librive_native.so',
].any((p) => File(p).existsSync());

void main() {
  test('every animal ships a PNG and a Rive file', () {
    for (final key in animals.keys) {
      expect(File('assets/art/$key.png').existsSync(), isTrue, reason: key);
      expect(File('assets/art/$key.riv').existsSync(), isTrue, reason: key);
    }
  });

  test(
    'Rive animals: reveal on entry, celebrate on the match trigger, then settle',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final key in animals.keys) {
        final file = await rive.File.decode(
          File('assets/art/$key.riv').readAsBytesSync(),
          riveFactory: rive.Factory.flutter,
        );
        expect(file, isNotNull, reason: key);
        final artboard = file!.defaultArtboard()!;
        expect(artboard.animationCount(), 2, reason: key);
        final machine = artboard.defaultStateMachine()!;
        // Entry → reveal is a one-shot clip that stops on its own.
        machine.advanceAndApply(0);
        expect(machine.advanceAndApply(1 / 60), isTrue, reason: '$key reveal');
        machine.advanceAndApply(1);
        expect(machine.advanceAndApply(1 / 60), isFalse, reason: '$key rests');
        // ignore: deprecated_member_use
        final trigger = machine.trigger('match');
        expect(trigger, isNotNull, reason: key);
        trigger!.fire();
        expect(machine.advanceAndApply(.1), isTrue, reason: '$key celebrate');
        machine.advanceAndApply(1);
        expect(
          machine.advanceAndApply(1 / 60),
          isFalse,
          reason: '$key settles: no per-frame work once a clip ends',
        );
        machine.dispose();
        artboard.dispose();
        file.dispose();
      }
    },
    skip: _runtimeAvailable ? false : 'rive_native desktop library missing',
  );
}
