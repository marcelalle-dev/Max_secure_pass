import 'dart:async';

import 'package:flutter/services.dart';

/// Copie une valeur sensible et vide le presse-papiers après [clearAfter],
/// sauf si l'utilisateur a copié autre chose entre-temps.
class SecureClipboard {
  static const clearAfter = Duration(seconds: 30);

  static Timer? _timer;

  static Future<void> copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _timer?.cancel();
    _timer = Timer(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}
