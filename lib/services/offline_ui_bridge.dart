import 'package:flutter/foundation.dart';

class OfflineUiBridge {
  static final ValueNotifier<bool> openManager = ValueNotifier<bool>(false);

  static void requestOpenManager() {
    openManager.value = true;
  }

  static void consumeOpenManager() {
    openManager.value = false;
  }
}


