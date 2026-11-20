import 'package:jinhop/services/audio_service.dart';

class FakeAudioBackend implements AudioBackend {
  final List<String> calls = [];
  final List<double> rates = [];
  @override
  Future<void> preload(List<String> assets) async => calls.add('preload ${assets.length}');
  @override
  Future<void> play(String asset, {required double rate, required double volume}) async {
    calls.add('play $asset');
    rates.add(rate);
  }

  @override
  Future<void> startLoop(String asset, {required double volume}) async => calls.add('loop $asset');
  @override
  Future<void> stopLoop() async => calls.add('stopLoop');
  @override
  Future<void> pauseLoop() async => calls.add('pauseLoop');
  @override
  Future<void> resumeLoop() async => calls.add('resumeLoop');

  List<String> get plays => calls.where((c) => c.startsWith('play ')).map((c) => c.substring(5)).toList();
}
