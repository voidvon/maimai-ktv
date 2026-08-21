String formatPlaybackDuration(Duration value) {
  final int totalSeconds = value.inSeconds.clamp(0, 86399);
  final int minutes = (totalSeconds ~/ 60) % 60;
  final int seconds = totalSeconds % 60;
  final int hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    final String paddedMinutes = minutes.toString().padLeft(2, '0');
    final String paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$hours:$paddedMinutes:$paddedSeconds';
  }
  final String paddedSeconds = seconds.toString().padLeft(2, '0');
  return '$minutes:$paddedSeconds';
}
