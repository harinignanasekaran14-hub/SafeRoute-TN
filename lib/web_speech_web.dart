import 'dart:js_interop';

@JS('speechSynthesis')
external _SpeechSynthesis? get _speechSynthesis;

extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external void speak(JSObject utterance);
  external void cancel();
  external JSArray<_SpeechSynthesisVoice> getVoices();
  external set onvoiceschanged(JSFunction? callback);
}

extension type _SpeechSynthesisVoice._(JSObject _) implements JSObject {
  external String get name;
  external String get lang;
  external bool get default_;
  external bool get localService;
}

@JS('SpeechSynthesisUtterance')
extension type _SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external _SpeechSynthesisUtterance(String text);
  external set rate(num value);
  external set lang(String value);
  external set voice(_SpeechSynthesisVoice? voice);
}

class WebSpeechHelper {
  static bool _initialized = false;
  static final List<void Function()> _voicesChangedListeners = [];

  static bool get isSupported {
    try {
      return _speechSynthesis != null;
    } catch (_) {
      return false;
    }
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    try {
      final synth = _speechSynthesis;
      if (synth == null) return;
      synth.onvoiceschanged = (() {
        for (final listener in List.of(_voicesChangedListeners)) {
          try {
            listener();
          } catch (_) {}
        }
      }).toJS;
    } catch (_) {}
  }

  static void addVoicesChangedListener(void Function() listener) {
    _ensureInitialized();
    if (!_voicesChangedListeners.contains(listener)) {
      _voicesChangedListeners.add(listener);
    }
  }

  static void removeVoicesChangedListener(void Function() listener) {
    _voicesChangedListeners.remove(listener);
  }

  static List<String> get availableVoiceLangs {
    _ensureInitialized();
    try {
      final synth = _speechSynthesis;
      if (synth == null) return const [];
      final list = synth.getVoices().toDart;
      return list.map((v) => v.lang).toSet().toList();
    } catch (_) {
      return const [];
    }
  }

  static _SpeechSynthesisVoice? _findVoiceForLanguage(String bcp47) {
    _ensureInitialized();
    try {
      final synth = _speechSynthesis;
      if (synth == null) return null;
      final voices = synth.getVoices().toDart;
      if (voices.isEmpty) return null;

      final normTarget = bcp47.trim().toLowerCase().replaceAll('_', '-');
      final prefix = normTarget.contains('-')
          ? normTarget.split('-').first
          : (normTarget.length >= 2 ? normTarget.substring(0, 2) : normTarget);

      // 1. Exact BCP-47 match (e.g. 'ta-in' == 'ta-in')
      for (final v in voices) {
        final vLang = v.lang.trim().toLowerCase().replaceAll('_', '-');
        if (vLang == normTarget) {
          return v;
        }
      }

      // 2. Prefix match (e.g. 'ta-lk' or 'ta' matching 'ta')
      for (final v in voices) {
        final vLang = v.lang.trim().toLowerCase().replaceAll('_', '-');
        if (vLang.startsWith(prefix) || normTarget.startsWith(vLang)) {
          return v;
        }
      }

      // 3. Name fallback (e.g. voice name contains language name)
      final langName = _langCodeToName(prefix);
      if (langName != null) {
        for (final v in voices) {
          if (v.name.toLowerCase().contains(langName)) {
            return v;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _langCodeToName(String prefix) {
    switch (prefix) {
      case 'ta':
        return 'tamil';
      case 'hi':
        return 'hindi';
      case 'te':
        return 'telugu';
      case 'ml':
        return 'malayalam';
      case 'kn':
        return 'kannada';
      case 'en':
        return 'english';
      default:
        return null;
    }
  }

  static bool hasVoiceForLanguage(String bcp47) {
    final v = _findVoiceForLanguage(bcp47);
    return v != null;
  }

  static void unlock() {
    try {
      final synth = _speechSynthesis;
      if (synth == null) return;
      final utterance = _SpeechSynthesisUtterance(' ');
      synth.speak(utterance);
    } catch (_) {}
  }

  /// Speaks [text] in [lang] (BCP-47 code).
  /// Returns `true` if a matching voice was found and spoken.
  /// Returns `false` if no voice is available for this language (does NOT speak in wrong language).
  static bool speak(String text, {String lang = 'en-IN'}) {
    try {
      final synth = _speechSynthesis;
      if (synth == null) return false;

      final voice = _findVoiceForLanguage(lang);
      if (voice == null) {
        // Requirement 8: Do not silently speak in another language.
        return false;
      }

      synth.cancel();
      final utterance = _SpeechSynthesisUtterance(text);
      utterance.voice = voice;
      utterance.lang = voice.lang;
      utterance.rate = 1.0;
      synth.speak(utterance);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void stop() {
    try {
      final synth = _speechSynthesis;
      synth?.cancel();
    } catch (_) {}
  }
}
