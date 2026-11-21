class WebSpeechHelper {
  static bool mockSupported = false;
  static Map<String, bool>? mockAvailableVoices;
  static final List<void Function()> _listeners = [];
  static final List<String> spokenTexts = [];
  static final List<String> spokenLangs = [];

  static bool get isSupported => mockSupported;

  static void addVoicesChangedListener(void Function() listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  static void removeVoicesChangedListener(void Function() listener) {
    _listeners.remove(listener);
  }

  static void triggerVoicesChanged() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  static List<String> get availableVoiceLangs =>
      mockAvailableVoices?.keys.toList() ?? const [];

  static bool hasVoiceForLanguage(String bcp47) {
    if (mockAvailableVoices != null) {
      final norm = bcp47.trim().toLowerCase().replaceAll('_', '-');
      final prefix = norm.contains('-') ? norm.split('-').first : norm;
      for (final entry in mockAvailableVoices!.entries) {
        final keyNorm = entry.key.trim().toLowerCase().replaceAll('_', '-');
        if (keyNorm == norm || keyNorm.startsWith(prefix) || norm.startsWith(keyNorm)) {
          return entry.value;
        }
      }
      return false;
    }
    return false;
  }

  static bool speak(String text, {String lang = 'en-IN'}) {
    if (!hasVoiceForLanguage(lang)) {
      return false;
    }
    spokenTexts.add(text);
    spokenLangs.add(lang);
    return true;
  }

  static void stop() {}
  static void unlock() {}

  static void resetMock() {
    mockSupported = false;
    mockAvailableVoices = null;
    _listeners.clear();
    spokenTexts.clear();
    spokenLangs.clear();
  }
}
