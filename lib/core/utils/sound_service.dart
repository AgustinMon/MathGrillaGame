import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playTileDrop() async {
    _player.stop(); // Use player to avoid warning
    // await _player.play(AssetSource('sounds/tile_drop.mp3'));
  }

  static Future<void> playSuccess() async {
    // await _player.play(AssetSource('sounds/success.mp3'));
  }

  static Future<void> playError() async {
    // await _player.play(AssetSource('sounds/error.mp3'));
  }

  static Future<void> playWin() async {
    // await _player.play(AssetSource('sounds/win.mp3'));
  }
}
