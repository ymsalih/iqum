/// Server time advances with elapsed ticks, independently of phone date settings.
/// Without a server sample, the initial device time is only an offline fallback.
class GameClock {
  GameClock({int Function()? wallTime, int Function()? elapsedTime}) {
    final watch = Stopwatch()..start();
    _elapsed = elapsedTime ?? (() => watch.elapsedMilliseconds);
    _anchor = (wallTime ?? (() => DateTime.now().millisecondsSinceEpoch))();
    _anchorTick = _elapsed();
  }

  late final int Function() _elapsed;
  late int _anchor, _anchorTick;
  bool synchronized = false;
  int _lastSample = -1;
  int get tick => _elapsed();
  int get now => _anchor + tick - _anchorTick;

  void synchronize(int serverNow, int requestStartedAt) {
    final receivedAt = tick;
    // A slower, older request must not overwrite a newer clock sample.
    if (requestStartedAt < _lastSample || serverNow < 0) return;
    _lastSample = requestStartedAt;
    _anchor = serverNow + (receivedAt - requestStartedAt) ~/ 2;
    _anchorTick = receivedAt;
    synchronized = true;
  }
}
