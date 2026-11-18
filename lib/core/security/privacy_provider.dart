import 'package:flutter/foundation.dart';

class PrivacyProvider extends ChangeNotifier {
  bool _isPrivacyMode = false;

  bool get isPrivacyMode => _isPrivacyMode;

  void togglePrivacyMode() {
    _isPrivacyMode = !_isPrivacyMode;
    notifyListeners();
  }

  void setPrivacyMode(bool value) {
    if (_isPrivacyMode != value) {
      _isPrivacyMode = value;
      notifyListeners();
    }
  }

  /// Formats currency with privacy mask if active
  String mask(String actualAmount) {
    if (_isPrivacyMode) {
      return '₹ ••••••';
    }
    return actualAmount;
  }
}
