import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/trigger.dart';

class FeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> triggerFeedback(TriggerAction action) async {
    switch (action) {
      case TriggerAction.sound:
        await _playSound();
        break;
      case TriggerAction.vibrate:
        await _vibrate();
        break;
      case TriggerAction.soundAndVibrate:
        await Future.wait([_playSound(), _vibrate()]);
        break;
    }
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 1000);
    }
  }
}
