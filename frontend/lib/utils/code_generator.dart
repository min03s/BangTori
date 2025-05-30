import 'dart:math';

class CodeGenerator {
  static String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  static String generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static List<String> profileColors = [
    '#FF5722', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFC107', '#FF9800', '#FF5722', '#795548',
  ];

  static String getRandomColor() {
    final random = Random();
    return profileColors[random.nextInt(profileColors.length)];
  }
}