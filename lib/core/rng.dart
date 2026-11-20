// Deterministic PRNG (xorshift32 with a seed scrambler). PURE DART.
// We do not use dart:math Random so the daily puzzle is identical on every
// device and every Dart SDK version.

class Rng {
  int _s;

  Rng(int seed) : _s = _scramble(seed) {
    for (var i = 0; i < 8; i++) {
      nextU32();
    }
  }

  static int _scramble(int seed) {
    var z = (seed ^ 0x9E3779B9) & 0xFFFFFFFF;
    z = ((z ^ (z >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    z = ((z ^ (z >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    z = (z ^ (z >> 16)) & 0xFFFFFFFF;
    return z == 0 ? 0x6D2B79F5 : z;
  }

  int nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  /// Uniform int in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError('max must be > 0');
    return nextU32() % max;
  }

  double nextDouble() => nextU32() / 4294967296.0;

  bool chance(double p) => nextDouble() < p;

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  T pick<T>(List<T> list) => list[nextInt(list.length)];
}
