import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/domain/game_clock.dart';
import 'package:iqum/domain/models.dart';

void main() {
  test('phone date changes cannot advance countdowns or grant a heart', () {
    var wall = 1000000, elapsed = 0;
    final clock = GameClock(wallTime: () => wall, elapsedTime: () => elapsed);
    final life = LifeState(observedAt: clock.now).spend(clock.now);
    clock.synchronize(1000000, 0);
    wall += const Duration(days: 365).inMilliseconds;
    elapsed += 15000;
    expect(clock.now, 1015000);
    expect(life.at(clock.now).count, 3);
    wall = 0;
    elapsed += 1785000;
    expect(clock.now, 2800000);
    expect(life.at(clock.now).count, 4);
  });
  test('server sample corrects a forged startup date and uses elapsed RTT', () {
    var elapsed = 0;
    final clock = GameClock(
      wallTime: () => 9999999999999,
      elapsedTime: () => elapsed,
    );
    expect(clock.synchronized, false);
    final start = clock.tick;
    elapsed = 200;
    clock.synchronize(1000000, start);
    expect(clock.now, 1000100);
    elapsed = 500;
    expect(clock.now, 1000400);
    expect(clock.synchronized, true);
  });
  test('an older request cannot overwrite a newer server time sample', () {
    var elapsed = 100;
    final clock = GameClock(wallTime: () => 0, elapsedTime: () => elapsed);
    elapsed = 300;
    clock.synchronize(1000, 200);
    elapsed = 400;
    clock.synchronize(99999999, 100);
    expect(clock.now, 1150);
  });
  test('a future-dated cached life is rebased without gaining hearts', () {
    final life = LifeState.fromJson(
      {'count': 1, 'observedAt': 999999999, 'nextAt': 1000899999},
      1000,
      trustedTime: true,
    );
    expect(life.count, 1);
    expect(life.observedAt, 1000);
    expect(life.nextAt, 901000);
    expect(life.at(900999).count, 1);
    expect(life.at(901000).count, 2);
    final invalid = LifeState.fromJson(
      {'count': 0, 'observedAt': 999999999, 'nextAt': -1},
      1000,
      trustedTime: true,
    );
    expect(invalid.count, 0);
    expect(invalid.nextAt, 1801000);
  });
}
