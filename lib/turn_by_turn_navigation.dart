import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'web_speech.dart';

/// Announcement stage for upcoming turn manoeuvres.
enum AnnouncementStage {
  none,
  stage500m,
  stage150m,
  stageNow,
  stageArrived,
}

/// Supported navigation voice and visual languages in SafeRoute TN 2.0.
enum NavLanguage {
  tamil(
    code: 'ta',
    bcp47: 'ta-IN',
    displayName: 'தமிழ்',
    englishName: 'Tamil',
    shortCode: 'TA',
  ),
  english(
    code: 'en',
    bcp47: 'en-IN',
    displayName: 'English',
    englishName: 'English',
    shortCode: 'EN',
  ),
  hindi(
    code: 'hi',
    bcp47: 'hi-IN',
    displayName: 'हिन्दी',
    englishName: 'Hindi',
    shortCode: 'HI',
  ),
  telugu(
    code: 'te',
    bcp47: 'te-IN',
    displayName: 'తెలుగు',
    englishName: 'Telugu',
    shortCode: 'TE',
  ),
  malayalam(
    code: 'ml',
    bcp47: 'ml-IN',
    displayName: 'മലയാളം',
    englishName: 'Malayalam',
    shortCode: 'ML',
  ),
  kannada(
    code: 'kn',
    bcp47: 'kn-IN',
    displayName: 'ಕನ್ನಡ',
    englishName: 'Kannada',
    shortCode: 'KN',
  );

  final String code;
  final String bcp47;
  final String displayName;
  final String englishName;
  final String shortCode;

  const NavLanguage({
    required this.code,
    required this.bcp47,
    required this.displayName,
    required this.englishName,
    required this.shortCode,
  });

  static NavLanguage fromBcp47(String? value) {
    if (value == null || value.trim().isEmpty) return NavLanguage.english;
    final norm = value.toLowerCase().trim().replaceAll('_', '-');
    for (final lang in NavLanguage.values) {
      if (lang.bcp47.toLowerCase() == norm ||
          lang.code.toLowerCase() == norm ||
          norm.startsWith('${lang.code.toLowerCase()}-')) {
        return lang;
      }
    }
    return NavLanguage.english;
  }
}

/// Comprehensive localization engine for navigation visual cards and voice announcements.
class NavigationLocalizer {
  static ({String instruction, String shortInstruction, IconData icon})
      buildInstructionAndIcon({
    required String type,
    required String? modifier,
    required String roadName,
    required int? exitNumber,
    NavLanguage lang = NavLanguage.english,
  }) {
    final hasRoad = roadName.trim().isNotEmpty;
    final cleanModifier = modifier?.replaceAll('_', ' ').trim();
    final cleanRoad = roadName.trim();

    switch (type) {
      case 'depart':
        return (
          instruction: _departInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _departShort(lang),
          icon: Icons.navigation_rounded,
        );

      case 'arrive':
        return (
          instruction: _arriveInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _arriveShort(lang),
          icon: Icons.place_rounded,
        );

      case 'roundabout':
      case 'rotary':
        if (exitNumber != null) {
          return (
            instruction: _roundaboutExitInstruction(exitNumber, cleanRoad, hasRoad, lang),
            shortInstruction: _roundaboutExitShort(exitNumber, lang),
            icon: Icons.roundabout_right_rounded,
          );
        }
        return (
          instruction: _roundaboutEnterInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _roundaboutEnterShort(lang),
          icon: Icons.roundabout_right_rounded,
        );

      case 'roundabout turn':
        return (
          instruction: _roundaboutTurnInstruction(cleanModifier, cleanRoad, hasRoad, lang),
          shortInstruction: _roundaboutTurnShort(cleanModifier, lang),
          icon: Icons.roundabout_right_rounded,
        );

      case 'fork':
        if (cleanModifier == 'left' || cleanModifier == 'slight left') {
          return (
            instruction: _forkLeftInstruction(cleanRoad, hasRoad, lang),
            shortInstruction: _forkLeftShort(lang),
            icon: Icons.fork_left_rounded,
          );
        } else if (cleanModifier == 'right' || cleanModifier == 'slight right') {
          return (
            instruction: _forkRightInstruction(cleanRoad, hasRoad, lang),
            shortInstruction: _forkRightShort(lang),
            icon: Icons.fork_right_rounded,
          );
        }
        return (
          instruction: _forkGenericInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _forkGenericShort(lang),
          icon: Icons.straight_rounded,
        );

      case 'merge':
        return (
          instruction: _mergeInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _mergeShort(lang),
          icon: Icons.merge_type_rounded,
        );

      case 'on ramp':
        return (
          instruction: _onRampInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _onRampShort(lang),
          icon: Icons.ramp_right_rounded,
        );

      case 'off ramp':
        return (
          instruction: _offRampInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _offRampShort(lang),
          icon: Icons.ramp_right_rounded,
        );

      case 'new name':
        return (
          instruction: _continueInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _continueShort(lang),
          icon: Icons.straight_rounded,
        );

      case 'continue':
        if (cleanModifier == 'uturn') {
          return (
            instruction: _continueUturnInstruction(cleanRoad, hasRoad, lang),
            shortInstruction: _uturnShort(lang),
            icon: Icons.u_turn_left_rounded,
          );
        }
        return (
          instruction: _continueStraightInstruction(cleanRoad, hasRoad, lang),
          shortInstruction: _continueStraightShort(lang),
          icon: Icons.straight_rounded,
        );

      case 'turn':
      case 'end of road':
      default:
        switch (cleanModifier) {
          case 'left':
            return (
              instruction: _turnLeftInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _turnLeftShort(lang),
              icon: Icons.turn_left_rounded,
            );
          case 'right':
            return (
              instruction: _turnRightInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _turnRightShort(lang),
              icon: Icons.turn_right_rounded,
            );
          case 'slight left':
            return (
              instruction: _slightLeftInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _slightLeftShort(lang),
              icon: Icons.turn_slight_left_rounded,
            );
          case 'slight right':
            return (
              instruction: _slightRightInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _slightRightShort(lang),
              icon: Icons.turn_slight_right_rounded,
            );
          case 'sharp left':
            return (
              instruction: _sharpLeftInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _sharpLeftShort(lang),
              icon: Icons.turn_sharp_left_rounded,
            );
          case 'sharp right':
            return (
              instruction: _sharpRightInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _sharpRightShort(lang),
              icon: Icons.turn_sharp_right_rounded,
            );
          case 'uturn':
            return (
              instruction: _uturnInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _uturnShort(lang),
              icon: Icons.u_turn_left_rounded,
            );
          case 'straight':
            return (
              instruction: _continueStraightInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _continueStraightShort(lang),
              icon: Icons.straight_rounded,
            );
          default:
            return (
              instruction: _defaultInstruction(cleanRoad, hasRoad, lang),
              shortInstruction: _continueShort(lang),
              icon: Icons.straight_rounded,
            );
        }
    }
  }

  // --- Depart ---
  static String _departInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் பயணத்தைத் தொடங்கவும்' : 'இலக்கை நோக்கிச் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर यात्रा शुरू करें' : 'गंतव्य की ओर बढ़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో ప్రయాణాన్ని ప్రారంభించండి' : 'గమ్యస్థానం వైపు వెళ్లండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലൂടെ യാത്ര ആരംഭിക്കുക' : 'ലക്ഷ്യസ്ഥാനത്തേക്ക് പോവുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಪ್ರಯಾಣ ಪ್ರಾರಂಭಿಸಿ' : 'ಗಮ್ಯಸ್ಥಾನದ ಕಡೆಗೆ ತೆರಳಿ';
      case NavLanguage.english:
        return hasRoad ? 'Start route on $road' : 'Head toward destination';
    }
  }

  static String _departShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'பயணத்தைத் தொடங்கவும்';
      case NavLanguage.hindi:
        return 'यात्रा शुरू करें';
      case NavLanguage.telugu:
        return 'ప్రయాణాన్ని ప్రారంభించండి';
      case NavLanguage.malayalam:
        return 'യാത്ര ആരംഭിക്കുക';
      case NavLanguage.kannada:
        return 'ಪ್ರಯಾಣ ಪ್ರಾರಂಭಿಸಿ';
      case NavLanguage.english:
        return 'Start route';
    }
  }

  // --- Arrive ---
  static String _arriveInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் உங்கள் இலக்கை அடைந்துவிட்டீர்கள்' : 'இலக்கை அடைந்துவிட்டீர்கள்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर गंतव्य पर पहुंचें' : 'गंतव्य पर पहुंचें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వద్ద గమ్యస్థానానికి చేరుకోండి' : 'గమ్యస్థానానికి చేరుకోండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ൽ ലക്ഷ്യസ്ഥാനത്ത് എത്തുക' : 'ലക്ഷ്യസ്ഥാനത്ത് എത്തുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಗಮ್ಯಸ್ಥಾನವನ್ನು ತಲುಪಿ' : 'ಗಮ್ಯಸ್ಥಾನವನ್ನು ತಲುಪಿ';
      case NavLanguage.english:
        return hasRoad ? 'Arrive at destination on $road' : 'Arrive at destination';
    }
  }

  static String _arriveShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'இலக்கை அடையவும்';
      case NavLanguage.hindi:
        return 'गंतव्य पर पहुंचें';
      case NavLanguage.telugu:
        return 'గమ్యస్థానాన్ని చేరుకోండి';
      case NavLanguage.malayalam:
        return 'ലക്ഷ്യസ്ഥാനത്ത് എത്തുക';
      case NavLanguage.kannada:
        return 'ಗಮ್ಯಸ್ಥಾನ ತಲುಪಿ';
      case NavLanguage.english:
        return 'Arrive at destination';
    }
  }

  // --- Turn Left ---
  static String _turnLeftInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் இடதுபுறம் திரும்பவும்' : 'இடதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर बाएं मुड़ें' : 'बाएं मुड़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు ఎడమవైపు తిరగండి' : 'ఎడమవైపు తిరగండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് ഇടത്തോട്ട് തിരിയുക' : 'ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ಎಡಕ್ಕೆ ತಿರುಗಿ' : 'ಎಡಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'Turn left onto $road' : 'Turn left';
    }
  }

  static String _turnLeftShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'இடதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return 'बाएं मुड़ें';
      case NavLanguage.telugu:
        return 'ఎడమవైపు తిరగండి';
      case NavLanguage.malayalam:
        return 'ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ಎಡಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return 'Turn left';
    }
  }

  // --- Turn Right ---
  static String _turnRightInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் வலதுபுறம் திரும்பவும்' : 'வலதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर दाएं मुड़ें' : 'दाएं मुड़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు కుడివైపు తిరగండి' : 'కుడివైపు తిరగండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് വലത്തോട്ട് തിരിയുക' : 'വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ಬಲಕ್ಕೆ ತಿರುಗಿ' : 'ಬಲಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'Turn right onto $road' : 'Turn right';
    }
  }

  static String _turnRightShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வலதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return 'दाएं मुड़ें';
      case NavLanguage.telugu:
        return 'కుడివైపు తిరగండి';
      case NavLanguage.malayalam:
        return 'വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ಬಲಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return 'Turn right';
    }
  }

  // --- Slight Left ---
  static String _slightLeftInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் சற்று இடதுபுறம் செல்லவும்' : 'சற்று இடதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर हल्का बाएं चलें' : 'हल्का बाएं चलें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు స్వల్పంగా ఎడమవైపు వెళ్లండి' : 'స్వల్పంగా ఎడమవైపు వెళ్లండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് അല്പം ഇടത്തോട്ട് തിരിയുക' : 'അല്പം ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ಸ್ವಲ್ಪ ಎಡಕ್ಕೆ ಚಲಿಸಿ' : 'ಸ್ವಲ್ಪ ಎಡಕ್ಕೆ ಚಲಿಸಿ';
      case NavLanguage.english:
        return hasRoad ? 'Slight left onto $road' : 'Slight left';
    }
  }

  static String _slightLeftShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'சற்று இடதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return 'हल्का बाएं चलें';
      case NavLanguage.telugu:
        return 'స్వల్పంగా ఎడమవైపు వెళ్లండి';
      case NavLanguage.malayalam:
        return 'അല്പം ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ಸ್ವಲ್ಪ ಎಡಕ್ಕೆ ಚಲಿಸಿ';
      case NavLanguage.english:
        return 'Slight left';
    }
  }

  // --- Slight Right ---
  static String _slightRightInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் சற்று வலதுபுறம் செல்லவும்' : 'சற்று வலதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर हल्का दाएं चलें' : 'हल्का दाएं चलें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు స్వల్పంగా కుడివైపు వెళ్లండి' : 'స్వల్పంగా కుడివైపు వెళ్లండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് അല്പം വലത്തോട്ട് തിരിയുക' : 'അല്പം വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ಸ್ವಲ್ಪ ಬಲಕ್ಕೆ ಚಲಿಸಿ' : 'ಸ್ವಲ್ಪ ಬಲಕ್ಕೆ ಚಲಿಸಿ';
      case NavLanguage.english:
        return hasRoad ? 'Slight right onto $road' : 'Slight right';
    }
  }

  static String _slightRightShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'சற்று வலதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return 'हल्का दाएं चलें';
      case NavLanguage.telugu:
        return 'స్వల్పంగా కుడివైపు వెళ్లండి';
      case NavLanguage.malayalam:
        return 'അല്പം വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ಸ್ವಲ್ಪ ಬಲಕ್ಕೆ ಚಲಿಸಿ';
      case NavLanguage.english:
        return 'Slight right';
    }
  }

  // --- Sharp Left ---
  static String _sharpLeftInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் கூர்மையான இடதுபுறம் திரும்பவும்' : 'கூர்மையான இடதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर तेज बाएं मुड़ें' : 'तेज बाएं मुड़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు తీవ్రంగా ఎడమవైపు తిరగండి' : 'తీవ్రంగా ఎడమవైపు తిరగండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് തീവ്രമായി ഇടത്തോട്ട് തിരിയുക' : 'തീവ്രമായി ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ತೀಕ್ಷ್ಣವಾಗಿ ಎಡಕ್ಕೆ ತಿರುಗಿ' : 'ತೀಕ್ಷ್ಣವಾಗಿ ಎಡಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'Sharp left onto $road' : 'Sharp left';
    }
  }

  static String _sharpLeftShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'கூர்மையான இடதுபுறம்';
      case NavLanguage.hindi:
        return 'तेज बाएं मुड़ें';
      case NavLanguage.telugu:
        return 'తీవ్రంగా ఎడమవైపు తిరగండి';
      case NavLanguage.malayalam:
        return 'തീവ്രമായി ഇടത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ತೀಕ್ಷ್ಣವಾಗಿ ಎಡಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return 'Sharp left';
    }
  }

  // --- Sharp Right ---
  static String _sharpRightInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் கூர்மையான வலதுபுறம் திரும்பவும்' : 'கூர்மையான வலதுபுறம் திரும்பவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर तेज दाएं मुड़ें' : 'तेज दाएं मुड़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు తీవ్రంగా కుడివైపు తిరగండి' : 'తీవ్రంగా కుడివైపు తిరగండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് തീവ്രമായി വലത്തോട്ട് തിരിയുക' : 'തീവ്രമായി വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ತೀಕ್ಷ್ಣವಾಗಿ ಬಲಕ್ಕೆ ತಿರುಗಿ' : 'ತೀಕ್ಷ್ಣವಾಗಿ ಬಲಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'Sharp right onto $road' : 'Sharp right';
    }
  }

  static String _sharpRightShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'கூர்மையான வலதுபுறம்';
      case NavLanguage.hindi:
        return 'तेज दाएं मुड़ें';
      case NavLanguage.telugu:
        return 'తీవ్రంగా కుడివైపు తిరగండి';
      case NavLanguage.malayalam:
        return 'തീവ്രമായി വലത്തോട്ട് തിരിയുക';
      case NavLanguage.kannada:
        return 'ತೀಕ್ಷ್ಣವಾಗಿ ಬಲಕ್ಕೆ ತಿರುಗಿ';
      case NavLanguage.english:
        return 'Sharp right';
    }
  }

  // --- U-Turn ---
  static String _continueUturnInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் யு-டர்ன் எடுக்கவும்' : 'யு-டர்ன் எடுக்கவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर यू-टर्न लें' : 'यू-टर्न लें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో యూ-టర్న్ తీసుకోండి' : 'యూ-టర్న్ తీసుకోండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ൽ യു-ടേൺ എടുക്കുക' : 'യു-ടേൺ എടുക്കുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಯು-ಟರ್ನ್ ತೆಗೆದುಕೊಳ್ಳಿ' : 'ಯು-ಟರ್ನ್ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return hasRoad ? 'Make a U-turn on $road' : 'Make a U-turn';
    }
  }

  static String _uturnInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் யு-டர்ன் எடுக்கவும்' : 'யு-டர்ன் எடுக்கவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर यू-टर्न लें' : 'यू-टर्न लें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో యూ-టర్న్ తీసుకోండి' : 'యూ-టర్న్ తీసుకోండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ൽ യു-ടേൺ എടുക്കുക' : 'യു-ടേൺ എടുക്കുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಯು-ಟರ್ನ್ ತೆಗೆದುಕೊಳ್ಳಿ' : 'ಯು-ಟರ್ನ್ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return hasRoad ? 'Make a U-turn onto $road' : 'Make a U-turn';
    }
  }

  static String _uturnShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'யு-டர்ன் எடுக்கவும்';
      case NavLanguage.hindi:
        return 'यू-टर्न लें';
      case NavLanguage.telugu:
        return 'యూ-టర్న్ తీసుకోండి';
      case NavLanguage.malayalam:
        return 'യു-ടേൺ എടുക്കുക';
      case NavLanguage.kannada:
        return 'ಯು-ಟರ್ನ್ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return 'Make a U-turn';
    }
  }

  // --- Continue Straight ---
  static String _continueStraightInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் நேராக செல்லவும்' : 'நேராக செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर सीधे चलें' : 'सीधे चलें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో నేరుగా వెళ్లండి' : 'నేరుగా వెళ్లండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലൂടെ നേരെ പോവുക' : 'നേരെ പോവുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ನೇರವಾಗಿ ಮುಂದುವರಿಯಿರಿ' : 'ನೇರವಾಗಿ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return hasRoad ? 'Continue straight on $road' : 'Continue straight';
    }
  }

  static String _continueStraightShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'நேராக செல்லவும்';
      case NavLanguage.hindi:
        return 'सीधे चलें';
      case NavLanguage.telugu:
        return 'నేరుగా వెళ్లండి';
      case NavLanguage.malayalam:
        return 'നേരെ പോവുക';
      case NavLanguage.kannada:
        return 'ನೇರವಾಗಿ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return 'Continue straight';
    }
  }

  // --- Roundabout Exit ---
  static String _roundaboutExitInstruction(
      int exitNumber, String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad
            ? 'வட்டச்சாலையில் வெளியேறு $exitNumber-ல் $road-ல் செல்லவும்'
            : 'வட்டச்சாலையில் வெளியேறு $exitNumber-ல் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad
            ? 'गोलचक्कर पर निकास $exitNumber लेकर $road पर जाएं'
            : 'गोलचक्कर पर निकास $exitNumber लें';
      case NavLanguage.telugu:
        return hasRoad
            ? 'రౌండ్‌అబౌట్ వద్ద ఎగ్జిట్ $exitNumber తీసుకొని $road లోకి వెళ్లండి'
            : 'రౌండ్‌అబౌట్ వద్ద ఎగ్జిట్ $exitNumber తీసుకోండి';
      case NavLanguage.malayalam:
        return hasRoad
            ? 'റൗണ്ട് എബൗട്ടിൽ നിന്ന് എക്സിറ്റ് $exitNumber വഴി $road-ലേക്ക് പോവുക'
            : 'റൗണ്ട് എബൗട്ടിൽ നിന്ന് എക്സിറ്റ് $exitNumber എടുക്കുക';
      case NavLanguage.kannada:
        return hasRoad
            ? 'ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ ಎಕ್ಸಿಟ್ $exitNumber ತೆಗೆದುಕೊಂಡು $road ಗೆ ತೆರಳಿ'
            : 'ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ ಎಕ್ಸಿಟ್ $exitNumber ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return hasRoad
            ? 'At the roundabout, take exit $exitNumber onto $road'
            : 'At the roundabout, take exit $exitNumber';
    }
  }

  static String _roundaboutExitShort(int exitNumber, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வெளியேறு $exitNumber-ல் செல்லவும்';
      case NavLanguage.hindi:
        return 'निकास $exitNumber लें';
      case NavLanguage.telugu:
        return 'ఎగ్జిట్ $exitNumber తీసుకోండి';
      case NavLanguage.malayalam:
        return 'എക്സിറ്റ് $exitNumber എടുക്കുക';
      case NavLanguage.kannada:
        return 'ಎಕ್ಸಿಟ್ $exitNumber ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return 'Take exit $exitNumber';
    }
  }

  // --- Roundabout Enter ---
  static String _roundaboutEnterInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road நோக்கி வட்டச்சாலையில் நுழையவும்' : 'வட்டச்சாலையில் நுழையவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road की ओर गोलचक्कर में प्रवेश करें' : 'गोलचक्कर में प्रवेश करें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు రౌండ్‌అబౌట్ లోకి వెళ్లండి' : 'రౌండ్‌అబౌట్ లోకి వెళ్లండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് റൗണ്ട് എബൗട്ടിലൂടെ പ്രവേശിക്കുക' : 'റൗണ്ട് എബൗട്ടിലേക്ക് പ്രവേശിക്കുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಕಡೆಗೆ ರೌಂಡ್‌ಅಬೌಟ್‌ಗೆ ಪ್ರವೇಶಿಸಿ' : 'ರೌಂಡ್‌ಅಬೌಟ್‌ಗೆ ಪ್ರವೇಶಿಸಿ';
      case NavLanguage.english:
        return hasRoad ? 'Enter the roundabout toward $road' : 'Enter the roundabout';
    }
  }

  static String _roundaboutEnterShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வட்டச்சாலையில் நுழையவும்';
      case NavLanguage.hindi:
        return 'गोलचक्कर में प्रवेश करें';
      case NavLanguage.telugu:
        return 'రౌండ్‌అబౌట్ లోకి వెళ్లండి';
      case NavLanguage.malayalam:
        return 'റൗണ്ട് എബൗട്ടിലേക്ക് പ്രവേശിക്കുക';
      case NavLanguage.kannada:
        return 'ರೌಂಡ್‌ಅಬೌಟ್‌ಗೆ ಪ್ರವೇಶಿಸಿ';
      case NavLanguage.english:
        return 'Enter roundabout';
    }
  }

  // --- Roundabout Turn ---
  static String _roundaboutTurnInstruction(
      String? modifier, String road, bool hasRoad, NavLanguage lang) {
    final modStr = modifier != null ? ' $modifier' : '';
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? 'வட்டச்சாலையில்$modStr $road-ல் திரும்பவும்' : 'வட்டச்சாலையில் திரும்பவும்';
      case NavLanguage.hindi:
        return hasRoad ? 'गोलचक्कर पर$modStr $road पर मुड़ें' : 'गोलचक्कर पर मुड़ें';
      case NavLanguage.telugu:
        return hasRoad ? 'రౌండ్‌అబౌట్ వద్ద$modStr $road లోకి తిరగండి' : 'రౌండ్‌అబౌట్ వద్ద తిరగండి';
      case NavLanguage.malayalam:
        return hasRoad ? 'റൗണ്ട് എബൗട്ടിൽ$modStr $road-ലേക്ക് തിരിയുക' : 'റൗണ്ട് എബൗട്ടിൽ തിരിയുക';
      case NavLanguage.kannada:
        return hasRoad ? 'ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ$modStr $road ಕಡೆಗೆ ತಿರುಗಿ' : 'ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ ತಿರುಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'At the roundabout, turn$modStr onto $road' : 'At the roundabout, turn$modStr';
    }
  }

  static String _roundaboutTurnShort(String? modifier, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வட்டச்சாலையில் திரும்பவும்';
      case NavLanguage.hindi:
        return 'गोलचक्कर पर मुड़ें';
      case NavLanguage.telugu:
        return 'రౌండ్‌అబౌట్ వద్ద తిరగండి';
      case NavLanguage.malayalam:
        return 'റൗണ്ട് എബൗട്ടിൽ തിരിയുക';
      case NavLanguage.kannada:
        return 'ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ ತಿರುಗಿ';
      case NavLanguage.english:
        return modifier != null ? 'Turn $modifier' : 'Turn at roundabout';
    }
  }

  // --- Fork Left ---
  static String _forkLeftInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? 'பிரிவில் இடதுபுறம் $road-ல் செல்லவும்' : 'பிரிவில் இடதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? 'कांटे पर बाएं रहकर $road पर जाएं' : 'कांटे पर बाएं रहें';
      case NavLanguage.telugu:
        return hasRoad ? 'కవలకు వద్ద ఎడమవైపు $road లోకి వెళ్లండి' : 'ఎడమవైపు కొనసాగండి';
      case NavLanguage.malayalam:
        return hasRoad ? 'ഇടതുവശം ചേർന്ന് $road-ലേക്ക് പോവുക' : 'ഇടതുവശം ചേർന്ന് പോവുക';
      case NavLanguage.kannada:
        return hasRoad ? 'ಕವಲಿನಲ್ಲಿ ಎಡಕ್ಕೆ ಮುಂದುವರಿದು $road ಗೆ ತೆರಳಿ' : 'ಎಡಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return hasRoad ? 'Keep left at the fork onto $road' : 'Keep left at the fork';
    }
  }

  static String _forkLeftShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'இடதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return 'बाएं रहें';
      case NavLanguage.telugu:
        return 'ఎడమవైపు కొనసాగండి';
      case NavLanguage.malayalam:
        return 'ഇടതുവശം ചേരുക';
      case NavLanguage.kannada:
        return 'ಎಡಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return 'Keep left';
    }
  }

  // --- Fork Right ---
  static String _forkRightInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? 'பிரிவில் வலதுபுறம் $road-ல் செல்லவும்' : 'பிரிவில் வலதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? 'कांटे पर दाएं रहकर $road पर जाएं' : 'कांटे पर दाएं रहें';
      case NavLanguage.telugu:
        return hasRoad ? 'కవలకు వద్ద కుడివైపు $road లోకి వెళ్లండి' : 'కుడివైపు కొనసాగండి';
      case NavLanguage.malayalam:
        return hasRoad ? 'വലതുവശം ചേർന്ന് $road-ലേക്ക് പോവുക' : 'വലതുവശം ചേർന്ന് പോവുക';
      case NavLanguage.kannada:
        return hasRoad ? 'ಕವಲಿನಲ್ಲಿ ಬಲಕ್ಕೆ ಮುಂದುವರಿದು $road ಗೆ ತೆರಳಿ' : 'ಬಲಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return hasRoad ? 'Keep right at the fork onto $road' : 'Keep right at the fork';
    }
  }

  static String _forkRightShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வலதுபுறம் செல்லவும்';
      case NavLanguage.hindi:
        return 'दाएं रहें';
      case NavLanguage.telugu:
        return 'కుడివైపు కొనసాగండి';
      case NavLanguage.malayalam:
        return 'വലതുവശം ചേരുക';
      case NavLanguage.kannada:
        return 'ಬಲಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return 'Keep right';
    }
  }

  // --- Fork Generic ---
  static String _forkGenericInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? 'பிரிவில் $road வழியே செல்லவும்' : 'பிரிவில் தொடர்ந்து செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? 'कांटे पर $road पर जाएं' : 'कांटे पर आगे बढ़ें';
      case NavLanguage.telugu:
        return hasRoad ? 'కవలకు వద్ద $road లోకి వెళ్లండి' : 'కవలకు వద్ద కొనసాగండి';
      case NavLanguage.malayalam:
        return hasRoad ? 'ഫോർക്കിൽ നിന്ന് $road-ലേക്ക് പോവുക' : 'ഫോർക്കിൽ തുടരുക';
      case NavLanguage.kannada:
        return hasRoad ? 'ಕವಲಿನಲ್ಲಿ $road ಕಡೆಗೆ ಸಾಗಿ' : 'ಕವಲಿನಲ್ಲಿ ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return hasRoad ? 'Follow the fork onto $road' : 'Follow the fork';
    }
  }

  static String _forkGenericShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'பிரிவில் செல்லவும்';
      case NavLanguage.hindi:
        return 'कांटे पर जाएं';
      case NavLanguage.telugu:
        return 'కవలకు వద్ద వెళ్లండి';
      case NavLanguage.malayalam:
        return 'ഫോർക്കിൽ പോവുക';
      case NavLanguage.kannada:
        return 'ಕವಲಿನಲ್ಲಿ ಸಾಗಿ';
      case NavLanguage.english:
        return 'Follow fork';
    }
  }

  // --- Merge ---
  static String _mergeInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் இணையவும்' : 'சாலையில் இணையவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road में मिलें' : 'मार्ग में मिलें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో విలీనం కావండి' : 'విలీనం కావండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് ചേരുക' : 'ചേരുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಗೆ ವಿಲೀನವಾಗಿ' : 'ವಿಲೀನವಾಗಿ';
      case NavLanguage.english:
        return hasRoad ? 'Merge onto $road' : 'Merge';
    }
  }

  static String _mergeShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'இணையவும்';
      case NavLanguage.hindi:
        return 'मिलें';
      case NavLanguage.telugu:
        return 'విలీనం';
      case NavLanguage.malayalam:
        return 'ചേരുക';
      case NavLanguage.kannada:
        return 'ವಿಲೀನವಾಗಿ';
      case NavLanguage.english:
        return 'Merge';
    }
  }

  // --- On Ramp ---
  static String _onRampInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road சாய்வுபாதையில் செல்லவும்' : 'சாய்வுபாதையில் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road के लिए रैंप लें' : 'रैंप लें';
      case NavLanguage.telugu:
        return hasRoad ? '$road వైపు ర్యాంప్ తీసుకోండి' : 'ర్యాంప్ తీసుకోండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്ക് റാംപ് എടുക്കുക' : 'റാംപ് എടുക്കുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಗೆ ರ್ಯಾಂಪ್ ತೆಗೆದುಕೊಳ್ಳಿ' : 'ರ್ಯಾಂಪ್ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return hasRoad ? 'Take the ramp onto $road' : 'Take the ramp';
    }
  }

  static String _onRampShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'சாய்வுபாதை';
      case NavLanguage.hindi:
        return 'रैंप लें';
      case NavLanguage.telugu:
        return 'ర్యాంప్ తీసుకోండి';
      case NavLanguage.malayalam:
        return 'റാംപ് എടുക്കുക';
      case NavLanguage.kannada:
        return 'ರ್ಯಾಂಪ್ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return 'Take ramp';
    }
  }

  // --- Off Ramp ---
  static String _offRampInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road வெளியேறும் வழியில் செல்லவும்' : 'வெளியேறும் வழியில் செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road के लिए निकास लें' : 'निकास लें';
      case NavLanguage.telugu:
        return hasRoad ? '$road ఎగ్జిట్ తీసుకోండి' : 'ఎగ్జిట్ తీసుకోండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലേക്കുള്ള എക്സിറ്റ് എടുക്കുക' : 'എക്സിറ്റ് എടുക്കുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ಗೆ ನಿರ್ಗಮನ ತೆಗೆದುಕೊಳ್ಳಿ' : 'ನಿರ್ಗಮನ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return hasRoad ? 'Take the exit onto $road' : 'Take the exit';
    }
  }

  static String _offRampShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வெளியேறும் வழி';
      case NavLanguage.hindi:
        return 'निकास लें';
      case NavLanguage.telugu:
        return 'ఎగ్జిట్ తీసుకోండి';
      case NavLanguage.malayalam:
        return 'എക്സിറ്റ് എടുക്കുക';
      case NavLanguage.kannada:
        return 'ನಿರ್ಗಮನ ತೆಗೆದುಕೊಳ್ಳಿ';
      case NavLanguage.english:
        return 'Take exit';
    }
  }

  // --- Continue / New Name ---
  static String _continueInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் தொடர்ந்து செல்லவும்' : 'தொடர்ந்து செல்லவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर आगे बढ़ें' : 'आगे बढ़ें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో కొనసాగించండి' : 'కొనసాగించండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലൂടെ തുടരുക' : 'തുടരുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಮುಂದುವರಿಯಿರಿ' : 'ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return hasRoad ? 'Continue onto $road' : 'Continue on route';
    }
  }

  static String _continueShort(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'தொடர்ந்து செல்லவும்';
      case NavLanguage.hindi:
        return 'आगे बढ़ें';
      case NavLanguage.telugu:
        return 'కొనసాగించండి';
      case NavLanguage.malayalam:
        return 'തുടരുക';
      case NavLanguage.kannada:
        return 'ಮುಂದುವರಿಯಿರಿ';
      case NavLanguage.english:
        return 'Continue';
    }
  }

  // --- Default ---
  static String _defaultInstruction(String road, bool hasRoad, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return hasRoad ? '$road-ல் தொடர்ந்து செல்லவும்' : 'வழியைப் பின்பற்றவும்';
      case NavLanguage.hindi:
        return hasRoad ? '$road पर आगे बढ़ें' : 'हाइलाइट किए गए मार्ग पर चलें';
      case NavLanguage.telugu:
        return hasRoad ? '$road లో కొనసాగించండి' : 'రూట్ ను అనుసరించండి';
      case NavLanguage.malayalam:
        return hasRoad ? '$road-ലൂടെ തുടരുക' : 'റൂട്ട് പിന്തുടരുക';
      case NavLanguage.kannada:
        return hasRoad ? '$road ನಲ್ಲಿ ಮುಂದುವರಿಯಿರಿ' : 'ಮಾರ್ಗವನ್ನು ಅನುಸರಿಸಿ';
      case NavLanguage.english:
        return hasRoad ? 'Continue onto $road' : 'Follow the highlighted route';
    }
  }

  // ==========================================
  // VOICE ANNOUNCEMENT GENERATOR
  // ==========================================
  static String generateVoiceAnnouncement({
    required RouteStep step,
    required AnnouncementStage stage,
    required double distanceMeters,
    required NavLanguage lang,
  }) {
    if (stage == AnnouncementStage.stageArrived) {
      return getDestinationArrivalAnnouncement(lang);
    }

    if (step.maneuverType == 'arrive') {
      switch (stage) {
        case AnnouncementStage.stage500m:
          switch (lang) {
            case NavLanguage.tamil:
              return '500 மீட்டரில் உங்கள் இலக்கை அடைவீர்கள்.';
            case NavLanguage.hindi:
              return '500 मीटर में आप अपने गंतव्य पर पहुंच जाएंगे।';
            case NavLanguage.telugu:
              return '500 మీటర్లలో మీరు మీ గమ్యాన్ని చేరుకుంటారు.';
            case NavLanguage.malayalam:
              return '500 മീറ്ററിൽ നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്ത് എത്തും.';
            case NavLanguage.kannada:
              return '500 ಮೀಟರ್‌ಗಳಲ್ಲಿ ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನ ತಲುಪುತ್ತೀರಿ.';
            case NavLanguage.english:
              return 'In 500 metres, you will arrive at your destination.';
          }
        case AnnouncementStage.stage150m:
          switch (lang) {
            case NavLanguage.tamil:
              return 'நீங்கள் விரைவில் இலக்கை அடைந்துவிடுவீர்கள்.';
            case NavLanguage.hindi:
              return 'आप अपने गंतव्य के करीब हैं।';
            case NavLanguage.telugu:
              return 'మీరు మీ గమ్యస్థానానికి చేరువలో ఉన్నారు.';
            case NavLanguage.malayalam:
              return 'നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്തിന് അടുത്താണ്.';
            case NavLanguage.kannada:
              return 'ನೀವು ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನದ ಸಮೀಪದಲ್ಲಿದ್ದೀರಿ.';
            case NavLanguage.english:
              return 'You are almost at your destination.';
          }
        case AnnouncementStage.stageNow:
        case AnnouncementStage.stageArrived:
          return getDestinationArrivalAnnouncement(lang);
        default:
          switch (lang) {
            case NavLanguage.tamil:
              return 'இலக்கை நோக்கித் தொடரவும்.';
            case NavLanguage.hindi:
              return 'गंतव्य की ओर जारी रखें।';
            case NavLanguage.telugu:
              return 'గమ్యస్థానానికి కొనసాగించండి.';
            case NavLanguage.malayalam:
              return 'ലക്ഷ്യസ്ഥാനത്തേക്ക് തുടരുക.';
            case NavLanguage.kannada:
              return 'ಗಮ್ಯಸ್ಥಾನಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ.';
            case NavLanguage.english:
              return 'Continue to destination.';
          }
      }
    }

    // Standard turn / maneuver announcement
    final actionFull = step.localizedInstruction(lang);
    final actionShort = step.localizedShortInstruction(lang);

    switch (lang) {
      case NavLanguage.tamil:
        switch (stage) {
          case AnnouncementStage.stage500m:
            return '500 மீட்டரில் $actionFull.';
          case AnnouncementStage.stage150m:
            return 'முன்னால் $actionFull.';
          case AnnouncementStage.stageNow:
            return 'இப்போது $actionFull.';
          default:
            return '$actionFull.';
        }

      case NavLanguage.hindi:
        switch (stage) {
          case AnnouncementStage.stage500m:
            return '500 मीटर में $actionFull।';
          case AnnouncementStage.stage150m:
            return 'आगे $actionFull।';
          case AnnouncementStage.stageNow:
            return 'अब $actionFull।';
          default:
            return '$actionFull।';
        }

      case NavLanguage.telugu:
        switch (stage) {
          case AnnouncementStage.stage500m:
            return '500 మీటర్లలో $actionFull.';
          case AnnouncementStage.stage150m:
            return 'ముందుగా $actionFull.';
          case AnnouncementStage.stageNow:
            return 'ఇప్పుడు $actionFull.';
          default:
            return '$actionFull.';
        }

      case NavLanguage.malayalam:
        switch (stage) {
          case AnnouncementStage.stage500m:
            return '500 മീറ്ററിൽ $actionFull.';
          case AnnouncementStage.stage150m:
            return 'മുന്നോട്ട് $actionFull.';
          case AnnouncementStage.stageNow:
            return 'ഇപ്പോൾ $actionFull.';
          default:
            return '$actionFull.';
        }

      case NavLanguage.kannada:
        switch (stage) {
          case AnnouncementStage.stage500m:
            return '500 ಮೀಟರ್‌ಗಳಲ್ಲಿ $actionFull.';
          case AnnouncementStage.stage150m:
            return 'ಮುಂದೆ $actionFull.';
          case AnnouncementStage.stageNow:
            return 'ಈಗ $actionFull.';
          default:
            return '$actionFull.';
        }

      case NavLanguage.english:
        final hasRoad = step.roadName.isNotEmpty;
        final roadSuffix = hasRoad ? ' onto ${step.roadName}' : '';
        switch (stage) {
          case AnnouncementStage.stage500m:
            return 'In 500 metres, ${actionShort.toLowerCase()}$roadSuffix.';
          case AnnouncementStage.stage150m:
            return '$actionShort ahead$roadSuffix.';
          case AnnouncementStage.stageNow:
            return '$actionShort now$roadSuffix.';
          default:
            return '$actionShort$roadSuffix.';
        }
    }
  }

  static String getDestinationArrivalAnnouncement(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'நீங்கள் உங்கள் இலக்கை அடைந்துவிட்டீர்கள்.';
      case NavLanguage.hindi:
        return 'आप अपने गंतव्य पर पहुंच गए हैं।';
      case NavLanguage.telugu:
        return 'మీరు మీ గమ్యాన్ని చేరుకున్నారు.';
      case NavLanguage.malayalam:
        return 'നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്ത് എത്തിച്ചേർന്നു.';
      case NavLanguage.kannada:
        return 'ನೀವು ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನವನ್ನು ತಲುಪಿದ್ದೀರಿ.';
      case NavLanguage.english:
        return 'You have arrived at your destination.';
    }
  }

  // --- Visual Card Helpers ---
  static String getMainInstruction({
    required RouteStep? currentStep,
    required bool isOffRoute,
    required bool isDestinationReached,
    required NavLanguage lang,
  }) {
    if (isOffRoute) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'வழியை விட்டு விலகிவிட்டீர்கள்';
        case NavLanguage.hindi:
          return 'मार्ग से बाहर';
        case NavLanguage.telugu:
          return 'రూట్ నుండి బయటపడ్డారు';
        case NavLanguage.malayalam:
          return 'റൂട്ട് മാറി സഞ്ചരിക്കുന്നു';
        case NavLanguage.kannada:
          return 'ಮಾರ್ಗ ತಪ್ಪಿದ್ದೀರಿ';
        case NavLanguage.english:
          return 'Off Route';
      }
    }

    if (isDestinationReached) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'இலக்கை அடைந்துவிட்டீர்கள்';
        case NavLanguage.hindi:
          return 'गंतव्य पर पहुंचे';
        case NavLanguage.telugu:
          return 'గమ్యస్థానం చేరుకున్నారు';
        case NavLanguage.malayalam:
          return 'ലക്ഷ്യസ്ഥാനത്ത് എത്തിച്ചേർന്നു';
        case NavLanguage.kannada:
          return 'ಗಮ್ಯಸ್ಥಾನ ತಲುಪಿದ್ದೀರಿ';
        case NavLanguage.english:
          return 'Destination Reached';
      }
    }

    return currentStep?.localizedShortInstruction(lang).toUpperCase() ??
        (lang == NavLanguage.tamil ? 'நேராக செல்லவும்' : 'CONTINUE STRAIGHT');
  }

  static String getSubDetails({
    required RouteStep? currentStep,
    required bool isOffRoute,
    required double? offRouteDistanceMeters,
    required bool isDestinationReached,
    required NavLanguage lang,
  }) {
    if (isOffRoute) {
      final dist = offRouteDistanceMeters?.round() ?? 50;
      switch (lang) {
        case NavLanguage.tamil:
          return '$dist மீ தொலைவில் · மீண்டும் இணைய திரும்பவும்';
        case NavLanguage.hindi:
          return '$dist मीटर दूर · वापस जुड़ने के लिए मुड़ें';
        case NavLanguage.telugu:
          return '$dist మీ దూరంలో · తిరిగి చేరడానికి తిరగండి';
        case NavLanguage.malayalam:
          return '$dist മീറ്റർ അകലെ · തിരികെ ചേരാൻ തിരിയുക';
        case NavLanguage.kannada:
          return '$dist ಮೀ ದೂರ · ಮತ್ತೆ ಸೇರಲು ತಿರುಗಿ';
        case NavLanguage.english:
          return '$dist m away · Turn around to rejoin';
      }
    }

    if (isDestinationReached) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'நீங்கள் உங்கள் இலக்கை அடைந்துவிட்டீர்கள்';
        case NavLanguage.hindi:
          return 'आप अपने गंतव्य पर पहुंच गए हैं';
        case NavLanguage.telugu:
          return 'మీరు మీ గమ్యాన్ని చేరుకున్నారు';
        case NavLanguage.malayalam:
          return 'നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്ത് എത്തിച്ചേർന്നു';
        case NavLanguage.kannada:
          return 'ನೀವು ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನವನ್ನು ತಲುಪಿದ್ದೀರಿ';
        case NavLanguage.english:
          return 'You have reached your destination';
      }
    }

    if (currentStep != null && currentStep.roadName.isNotEmpty) {
      switch (lang) {
        case NavLanguage.tamil:
          return '${currentStep.roadName}-ல் செல்லவும்';
        case NavLanguage.hindi:
          return '${currentStep.roadName} पर जाएं';
        case NavLanguage.telugu:
          return '${currentStep.roadName} వైపు వెళ్లండి';
        case NavLanguage.malayalam:
          return '${currentStep.roadName}-ലേക്ക് പോവുക';
        case NavLanguage.kannada:
          return '${currentStep.roadName} ಕಡೆಗೆ ತೆರಳಿ';
        case NavLanguage.english:
          return 'onto ${currentStep.roadName}';
      }
    }

    return currentStep?.localizedInstruction(lang) ??
        (lang == NavLanguage.tamil
            ? 'வழியைப் பின்பற்றவும்'
            : 'Follow the highlighted corridor');
  }

  static String getThenPrefix(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'அடுத்து: ';
      case NavLanguage.hindi:
        return 'फिर: ';
      case NavLanguage.telugu:
        return 'తరువాత: ';
      case NavLanguage.malayalam:
        return 'തുടർന്ന്: ';
      case NavLanguage.kannada:
        return 'ನಂತರ: ';
      case NavLanguage.english:
        return 'Then: ';
    }
  }

  static String getVoiceUnavailableMessage(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'தமிழ் குரல் கிடைக்கவில்லை (காட்சி வழி காட்டுதல் தொடரும்)';
      case NavLanguage.hindi:
        return 'हिन्दी आवाज़ उपलब्ध नहीं है (दृश्य मार्गदर्शन सक्रिय)';
      case NavLanguage.telugu:
        return 'తెలుగు వాయిస్ అందుబాటులో లేదు (విజువల్ గైడెన్స్ క్రియాశీలం)';
      case NavLanguage.malayalam:
        return 'മലയാളം വോയ്സ് ലഭ്യമല്ല (വിഷ്വൽ ഗൈഡൻസ് സജീവം)';
      case NavLanguage.kannada:
        return 'ಕನ್ನಡ ಧ್ವನಿ ಲಭ್ಯವಿಲ್ಲ (ದೃಶ್ಯ ಮಾರ್ಗದರ್ಶನ ಸಕ್ರಿಯ)';
      case NavLanguage.english:
        return 'Voice not available in browser (visual guidance active)';
    }
  }

  static String formatDistance(double? meters, {NavLanguage lang = NavLanguage.english}) {
    if (meters == null || meters <= 0) {
      switch (lang) {
        case NavLanguage.tamil:
        case NavLanguage.telugu:
        case NavLanguage.malayalam:
        case NavLanguage.kannada:
          return '0 மீ';
        case NavLanguage.hindi:
          return '0 मी';
        case NavLanguage.english:
          return '0 m';
      }
    }
    if (meters >= 1000) {
      final val = (meters / 1000).toStringAsFixed(1);
      switch (lang) {
        case NavLanguage.tamil:
        case NavLanguage.telugu:
        case NavLanguage.malayalam:
        case NavLanguage.kannada:
          return '$val கி.மீ';
        case NavLanguage.hindi:
          return '$val किमी';
        case NavLanguage.english:
          return '$val km';
      }
    }
    final val = meters.round().toString();
    switch (lang) {
      case NavLanguage.tamil:
      case NavLanguage.telugu:
      case NavLanguage.malayalam:
      case NavLanguage.kannada:
        return '$val மீ';
      case NavLanguage.hindi:
        return '$val मी';
      case NavLanguage.english:
        return '$val m';
    }
  }

  static String getCockpitInstruction({
    required RouteStep? step,
    required String fallbackInstruction,
    required bool isOffRoute,
    required bool isDestinationReached,
    required NavLanguage lang,
  }) {
    if (isOffRoute) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'வழியை விட்டு விலகிவிட்டீர்கள் — மீண்டும் இணைய திரும்பவும்';
        case NavLanguage.hindi:
          return 'मार्ग से बाहर — वापस जुड़ने के लिए मुड़ें';
        case NavLanguage.telugu:
          return 'రూట్ నుండి బయటపడ్డారు — తిరిగి చేరడానికి తిరగండి';
        case NavLanguage.malayalam:
          return 'റൂട്ട് മാറി സഞ്ചരിക്കുന്നു — തിരികെ ചേരാൻ തിരിയുക';
        case NavLanguage.kannada:
          return 'ಮಾರ್ಗ ತಪ್ಪಿದ್ದೀರಿ — ಮತ್ತೆ ಸೇರಲು ತಿರುಗಿ';
        case NavLanguage.english:
          return 'Off Route — Turn around to rejoin';
      }
    }

    if (isDestinationReached) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'இலக்கை அடைந்துவிட்டீர்கள்!';
        case NavLanguage.hindi:
          return 'गंतव्य पर पहुंचे!';
        case NavLanguage.telugu:
          return 'గమ్యస్థానం చేరుకున్నారు!';
        case NavLanguage.malayalam:
          return 'ലക്ഷ്യസ്ഥാനത്ത് എത്തിച്ചേർന്നു!';
        case NavLanguage.kannada:
          return 'ಗಮ್ಯಸ್ಥಾನ ತಲುಪಿದ್ದೀರಿ!';
        case NavLanguage.english:
          return 'Destination reached!';
      }
    }

    if (step == null) {
      if (fallbackInstruction.trim().isNotEmpty) {
        return fallbackInstruction;
      }
      switch (lang) {
        case NavLanguage.tamil:
          return 'வழியில் தொடர்ந்து செல்லவும்';
        case NavLanguage.hindi:
          return 'मार्ग पर आगे बढ़ें';
        case NavLanguage.telugu:
          return 'మార్గంలో కొనసాగించండి';
        case NavLanguage.malayalam:
          return 'റൂട്ടിൽ തുടരുക';
        case NavLanguage.kannada:
          return 'ಮಾರ್ಗದಲ್ಲಿ ಮುಂದುವರಿಯಿರಿ';
        case NavLanguage.english:
          return 'Continue on route';
      }
    }

    final shortText = step.localizedShortInstruction(lang);
    final dist = step.distanceMeters;

    if (dist > 40) {
      final formattedDist = formatDistance(dist, lang: lang);
      switch (lang) {
        case NavLanguage.tamil:
          return '$formattedDist-ல் $shortText';
        case NavLanguage.hindi:
          return '$formattedDist में $shortText';
        case NavLanguage.telugu:
          return '$formattedDist లో $shortText';
        case NavLanguage.malayalam:
          return '$formattedDist-ൽ $shortText';
        case NavLanguage.kannada:
          return '$formattedDist ನಲ್ಲಿ $shortText';
        case NavLanguage.english:
          return '$shortText in $formattedDist';
      }
    } else {
      switch (lang) {
        case NavLanguage.tamil:
          return 'முன்னால் $shortText';
        case NavLanguage.hindi:
          return 'आगे $shortText';
        case NavLanguage.telugu:
          return 'ముందుగా $shortText';
        case NavLanguage.malayalam:
          return 'മുന്നോട്ട് $shortText';
        case NavLanguage.kannada:
          return 'ಮುಂದೆ $shortText';
        case NavLanguage.english:
          return '$shortText ahead';
      }
    }
  }

  static String getCockpitRoadDirectionContext({
    required String? roadName,
    required String destinationName,
    required bool isOffRoute,
    required double? offRouteDistanceMeters,
    required NavLanguage lang,
  }) {
    if (isOffRoute) {
      final dist = offRouteDistanceMeters?.round() ?? 50;
      switch (lang) {
        case NavLanguage.tamil:
          return 'பரிந்துரைக்கப்பட்ட பாதையிலிருந்து $dist மீ தொலைவில்';
        case NavLanguage.hindi:
          return 'अनुशंसित मार्ग से $dist मीटर दूर';
        case NavLanguage.telugu:
          return 'సిఫార్సు చేసిన మార్గం నుండి $dist మీ దూరంలో';
        case NavLanguage.malayalam:
          return 'ശുപാർശ ചെയ്ത റൂട്ടിൽ നിന്ന് $dist മീറ്റർ അകലെ';
        case NavLanguage.kannada:
          return 'ಶಿಫಾರಸು ಮಾಡಿದ ಮಾರ್ಗದಿಂದ $dist ಮೀ ದೂರ';
        case NavLanguage.english:
          return '$dist m away from recommended route';
      }
    }

    final destPlaceholder = destinationName.trim().isNotEmpty
        ? destinationName.trim()
        : getDestinationPlaceholder(lang);

    final cleanRoad = roadName?.trim();
    final hasRoad = cleanRoad != null && cleanRoad.isNotEmpty;

    if (hasRoad) {
      switch (lang) {
        case NavLanguage.tamil:
          return '$cleanRoad-ல் • $destPlaceholder நோக்கி';
        case NavLanguage.hindi:
          return '$cleanRoad पर • $destPlaceholder की ओर';
        case NavLanguage.telugu:
          return '$cleanRoad లో • $destPlaceholder వైపు';
        case NavLanguage.malayalam:
          return '$cleanRoad-ൽ • $destPlaceholder ലക്ഷ്യമാക്കി';
        case NavLanguage.kannada:
          return '$cleanRoad ನಲ್ಲಿ • $destPlaceholder ಕಡೆಗೆ';
        case NavLanguage.english:
          return 'On $cleanRoad • Toward $destPlaceholder';
      }
    } else {
      switch (lang) {
        case NavLanguage.tamil:
          return '$destPlaceholder நோக்கி';
        case NavLanguage.hindi:
          return '$destPlaceholder की ओर';
        case NavLanguage.telugu:
          return '$destPlaceholder వైపు';
        case NavLanguage.malayalam:
          return '$destPlaceholder ലക്ഷ്യമാക്കി';
        case NavLanguage.kannada:
          return '$destPlaceholder ಕಡೆಗೆ';
        case NavLanguage.english:
          return 'Toward $destPlaceholder';
      }
    }
  }

  static String getDestinationPlaceholder(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'இலக்கு';
      case NavLanguage.hindi:
        return 'गंतव्य';
      case NavLanguage.telugu:
        return 'గమ్యస్థానం';
      case NavLanguage.malayalam:
        return 'ലക്ഷ്യസ്ഥാനം';
      case NavLanguage.kannada:
        return 'ಗಮ್ಯಸ್ಥಾನ';
      case NavLanguage.english:
        return 'Destination';
    }
  }

  static String getOriginPlaceholder(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'தொடக்க இடம்';
      case NavLanguage.hindi:
        return 'प्रारंभिक बिंदु';
      case NavLanguage.telugu:
        return 'ప్రారంభ స్థానం';
      case NavLanguage.malayalam:
        return 'ആരംഭ സ്ഥലം';
      case NavLanguage.kannada:
        return 'ಪ್ರಾರಂಭಿಕ ಸ್ಥಳ';
      case NavLanguage.english:
        return 'Origin';
    }
  }

  static String getGpsWaitingMessage(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'சாதனத்தின் ஜிபிஎஸ் சிக்னலுக்காக காத்திருக்கிறது...';
      case NavLanguage.hindi:
        return 'डिवाइस जीपीएस सिग्नल की प्रतीक्षा कर रहा है...';
      case NavLanguage.telugu:
        return 'పరికర జీపీఎస్ సిగ్నల్ కోసం వేచి చూస్తోంది...';
      case NavLanguage.malayalam:
        return 'ഉപകരണ ജിപിഎസ് സിഗ്നലിനായി കാത്തിരിക്കുന്നു...';
      case NavLanguage.kannada:
        return 'ಸಾಧನದ ಜಿಪಿಎಸ್ ಸಿಗ್ನಲ್‌ಗಾಗಿ ಕಾಯಲಾಗುತ್ತಿದೆ...';
      case NavLanguage.english:
        return 'Waiting for device GPS signal...';
    }
  }

  static String getCockpitActionLabel(
    String actionKey, {
    required bool state,
    required NavLanguage lang,
    required String fallback,
  }) {
    if (lang == NavLanguage.english) {
      return fallback;
    }

    switch (actionKey) {
      case 'following':
        if (state) {
          switch (lang) {
            case NavLanguage.tamil:
              return 'பின்தொடர்கிறது';
            case NavLanguage.hindi:
              return 'फॉलो जारी';
            case NavLanguage.telugu:
              return 'ఫాలో అవుతున్నారు';
            case NavLanguage.malayalam:
              return 'പിന്തുടരുന്നു';
            case NavLanguage.kannada:
              return 'ಅನುಸರಿಸಲಾಗುತ್ತಿದೆ';
            case NavLanguage.english:
              return 'Following';
          }
        } else {
          switch (lang) {
            case NavLanguage.tamil:
              return 'மறுசீரமை';
            case NavLanguage.hindi:
              return 'रीसेंटर';
            case NavLanguage.telugu:
              return 'రీసెంటర్';
            case NavLanguage.malayalam:
              return 'റീസെന്റർ';
            case NavLanguage.kannada:
              return 'ಮರುಹೊಂದಿಸಿ';
            case NavLanguage.english:
              return 'Recenter';
          }
        }

      case 'voice':
        if (state) {
          switch (lang) {
            case NavLanguage.tamil:
              return 'குரல் ஆன்';
            case NavLanguage.hindi:
              return 'आवाज़ चालू';
            case NavLanguage.telugu:
              return 'వాయిస్ ఆన్';
            case NavLanguage.malayalam:
              return 'വോയ്സ് ഓൺ';
            case NavLanguage.kannada:
              return 'ಧ್ವನಿ ಆನ್';
            case NavLanguage.english:
              return 'Voice On';
          }
        } else {
          switch (lang) {
            case NavLanguage.tamil:
              return 'மௌனம்';
            case NavLanguage.hindi:
              return 'म्यूट';
            case NavLanguage.telugu:
              return 'మ్యూట్';
            case NavLanguage.malayalam:
              return 'മ്യൂട്ട്';
            case NavLanguage.kannada:
              return 'ಮ್ಯೂಟ್';
            case NavLanguage.english:
              return 'Muted';
          }
        }

      case 'report':
        switch (lang) {
          case NavLanguage.tamil:
            return 'சிக்கல் புகாரளி';
          case NavLanguage.hindi:
            return 'समस्या रिपोर्ट करें';
          case NavLanguage.telugu:
            return 'సమస్యను నివేదించండి';
          case NavLanguage.malayalam:
            return 'റിപ്പോർട്ട് ചെയ്യുക';
          case NavLanguage.kannada:
            return 'ವರದಿ ಮಾಡಿ';
          case NavLanguage.english:
            return 'Report Issue';
        }

      case 'share':
        if (state) {
          switch (lang) {
            case NavLanguage.tamil:
              return 'நேரலை பகிர்வு';
            case NavLanguage.hindi:
              return 'लाइव साझा';
            case NavLanguage.telugu:
              return 'లైవ్ షేరింగ్';
            case NavLanguage.malayalam:
              return 'ലൈവ് ഷെയറിംഗ്';
            case NavLanguage.kannada:
              return 'ಲೈವ್ ಹಂಚಿಕೆ';
            case NavLanguage.english:
              return 'Live Sharing';
          }
        } else {
          switch (lang) {
            case NavLanguage.tamil:
              return 'பயணம் பகிர்';
            case NavLanguage.hindi:
              return 'यात्रा साझा करें';
            case NavLanguage.telugu:
              return 'ట్రిప్ షేర్';
            case NavLanguage.malayalam:
              return 'യാത്ര പങ്കിടുക';
            case NavLanguage.kannada:
              return 'ಟ್ರಿಪ್ ಹಂಚಿಕೊಳ್ಳಿ';
            case NavLanguage.english:
              return 'Share Trip';
          }
        }

      case 'pause':
        if (state) {
          switch (lang) {
            case NavLanguage.tamil:
              return 'தொடரவும்';
            case NavLanguage.hindi:
              return 'पुनरारंभ';
            case NavLanguage.telugu:
              return 'పునఃప్రారంభించు';
            case NavLanguage.malayalam:
              return 'തുടരുക';
            case NavLanguage.kannada:
              return 'ಪುನರಾರಂಭಿಸಿ';
            case NavLanguage.english:
              return 'Resume';
          }
        } else {
          switch (lang) {
            case NavLanguage.tamil:
              return 'இடைநிறுத்து';
            case NavLanguage.hindi:
              return 'रोकें';
            case NavLanguage.telugu:
              return 'పాజ్';
            case NavLanguage.malayalam:
              return 'പോസ്';
            case NavLanguage.kannada:
              return 'ವಿರಾಮಗೊಳಿಸಿ';
            case NavLanguage.english:
              return 'Pause';
          }
        }

      case 'stop':
        switch (lang) {
          case NavLanguage.tamil:
            return 'நிறுத்து';
          case NavLanguage.hindi:
            return 'रोकें';
          case NavLanguage.telugu:
            return 'ఆపండి';
          case NavLanguage.malayalam:
            return 'നിർത്തുക';
          case NavLanguage.kannada:
            return 'ನಿಲ್ಲಿಸಿ';
          case NavLanguage.english:
            return 'Stop';
        }

      default:
        return fallback;
    }
  }

  static String getFromPrefix(String fromName, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'தொடக்கம்: $fromName';
      case NavLanguage.hindi:
        return 'प्रस्थान: $fromName';
      case NavLanguage.telugu:
        return 'నుండి: $fromName';
      case NavLanguage.malayalam:
        return 'ആരംഭം: $fromName';
      case NavLanguage.kannada:
        return 'ಇಂದ: $fromName';
      case NavLanguage.english:
        return 'From: $fromName';
    }
  }

  static String getRouteNumberBadge(int routeNumber, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வழிப்பாதை $routeNumber';
      case NavLanguage.hindi:
        return 'मार्ग $routeNumber';
      case NavLanguage.telugu:
        return 'మార్గం $routeNumber';
      case NavLanguage.malayalam:
        return 'റൂട്ട് $routeNumber';
      case NavLanguage.kannada:
        return 'ಮಾರ್ಗ $routeNumber';
      case NavLanguage.english:
        return 'Route $routeNumber';
    }
  }

  static String getVehicleName(String vehicle, NavLanguage lang) {
    if (lang == NavLanguage.english) return vehicle;
    final vLower = vehicle.toLowerCase().trim();
    if (vLower.contains('car')) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'கார்';
        case NavLanguage.hindi:
          return 'कार';
        case NavLanguage.telugu:
          return 'కారు';
        case NavLanguage.malayalam:
          return 'കാർ';
        case NavLanguage.kannada:
          return 'ಕಾರು';
        case NavLanguage.english:
          return 'Car';
      }
    }
    if (vLower.contains('motor') || vLower.contains('bike') || vLower.contains('two')) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'இருசக்கர வாகனம்';
        case NavLanguage.hindi:
          return 'बाइक';
        case NavLanguage.telugu:
          return 'బైక్';
        case NavLanguage.malayalam:
          return 'ബൈക്ക്';
        case NavLanguage.kannada:
          return 'ಬೈಕ್';
        case NavLanguage.english:
          return 'Bike';
      }
    }
    if (vLower.contains('bi') || vLower.contains('cycle')) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'சைக்கிள்';
        case NavLanguage.hindi:
          return 'साइकिल';
        case NavLanguage.telugu:
          return 'సైకిల్';
        case NavLanguage.malayalam:
          return 'സൈക്കിൾ';
        case NavLanguage.kannada:
          return 'ಸೈಕಲ್';
        case NavLanguage.english:
          return 'Bicycle';
      }
    }
    if (vLower.contains('walk') || vLower.contains('pedestrian')) {
      switch (lang) {
        case NavLanguage.tamil:
          return 'நடப்பது';
        case NavLanguage.hindi:
          return 'पैदल';
        case NavLanguage.telugu:
          return 'నడక';
        case NavLanguage.malayalam:
          return 'നടത്തം';
        case NavLanguage.kannada:
          return 'ನಡಿಗೆ';
        case NavLanguage.english:
          return 'Walking';
      }
    }
    return vehicle;
  }

  static String getEtaLabel(String clockEtaStr, int remainingMinutes, NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'வருகை $clockEtaStr (~$remainingMinutes நிமிடம்)';
      case NavLanguage.hindi:
        return 'आगमन $clockEtaStr (~$remainingMinutes मिनट)';
      case NavLanguage.telugu:
        return 'చేరుకునే సమయం $clockEtaStr (~$remainingMinutes నిమి)';
      case NavLanguage.malayalam:
        return 'എത്തുന്ന സമയം $clockEtaStr (~$remainingMinutes മിനിറ്റ്)';
      case NavLanguage.kannada:
        return 'ಆಗಮನ $clockEtaStr (~$remainingMinutes ನಿಮಿಷ)';
      case NavLanguage.english:
        return 'ETA $clockEtaStr (~$remainingMinutes min)';
    }
  }

  static String getRemainingDistanceLabel(double remainingKm, double totalKm, NavLanguage lang) {
    final remStr = remainingKm.toStringAsFixed(1);
    final totStr = totalKm.toStringAsFixed(1);
    switch (lang) {
      case NavLanguage.tamil:
        return '$remStr கி.மீ மீதம் ($totStr கி.மீ)';
      case NavLanguage.hindi:
        return '$remStr किमी शेष ($totStr किमी)';
      case NavLanguage.telugu:
        return '$remStr కి.మీ మిగిలి ఉంది ($totStr కి.మీ)';
      case NavLanguage.malayalam:
        return '$remStr കി.മീ ബാക്കി ($totStr കി.മീ)';
      case NavLanguage.kannada:
        return '$remStr ಕಿ.ಮೀ ಬಾಕಿ ($totStr ಕಿ.ಮೀ)';
      case NavLanguage.english:
        return '$remStr km left ($totStr km)';
    }
  }

  static String getGpsStatusLabel(
    String key, {
    double? offRouteMeters,
    required NavLanguage lang,
  }) {
    switch (key) {
      case 'off_route':
        if (offRouteMeters != null) {
          final m = offRouteMeters.round();
          switch (lang) {
            case NavLanguage.tamil:
              return 'வழியை விட்டது ($mமீ)';
            case NavLanguage.hindi:
              return 'मार्ग से बाहर ($mमी)';
            case NavLanguage.telugu:
              return 'రూట్ నుండి బయట ($mమీ)';
            case NavLanguage.malayalam:
              return 'റൂട്ട് മാറി ($mമീ)';
            case NavLanguage.kannada:
              return 'ಮಾರ್ಗ ತಪ್ಪಿದೆ ($mಮೀ)';
            case NavLanguage.english:
              return 'OFF ROUTE (${m}m)';
          }
        }
        switch (lang) {
          case NavLanguage.tamil:
            return 'வழியை விட்டது';
          case NavLanguage.hindi:
            return 'मार्ग से बाहर';
          case NavLanguage.telugu:
            return 'రూట్ నుండి బయట';
          case NavLanguage.malayalam:
            return 'റൂട്ട് മാറി';
          case NavLanguage.kannada:
            return 'ಮಾರ್ಗ ತಪ್ಪಿದೆ';
          case NavLanguage.english:
            return 'OFF ROUTE';
        }

      case 'on_route':
        switch (lang) {
          case NavLanguage.tamil:
            return 'சரியான பாதையில் • ஜிபிஎஸ்';
          case NavLanguage.hindi:
            return 'मार्ग पर • जीपीएस';
          case NavLanguage.telugu:
            return 'సరైన మార్గంలో • జీపీఎస్';
          case NavLanguage.malayalam:
            return 'ശരിയായ റൂട്ടിൽ • ജിപിഎസ്';
          case NavLanguage.kannada:
            return 'ಸರಿಯಾದ ಮಾರ್ಗದಲ್ಲಿ • ಜಿಪಿಎಸ್';
          case NavLanguage.english:
            return 'ON ROUTE • GPS';
        }

      case 'stale':
        switch (lang) {
          case NavLanguage.tamil:
            return 'பழைய ஜிபிஎஸ்';
          case NavLanguage.hindi:
            return 'पुराना जीपीएस';
          case NavLanguage.telugu:
            return 'పాత జీపీఎస్';
          case NavLanguage.malayalam:
            return 'പഴയ ജിപിഎസ്';
          case NavLanguage.kannada:
            return 'ಹಳೆಯ ಜಿಪಿಎಸ್';
          case NavLanguage.english:
            return 'STALE GPS';
        }

      case 'acquiring':
        switch (lang) {
          case NavLanguage.tamil:
            return 'ஜிபிஎஸ் பெறுகிறது';
          case NavLanguage.hindi:
            return 'जीपीएस प्राप्त कर रहा है';
          case NavLanguage.telugu:
            return 'జీపీఎస్ పొందుతోంది';
          case NavLanguage.malayalam:
            return 'ജിപിഎസ് സ്വീകരിക്കുന്നു';
          case NavLanguage.kannada:
            return 'ಜಿಪಿಎಸ್ ಪಡೆಯಲಾಗುತ್ತಿದೆ';
          case NavLanguage.english:
            return 'ACQUIRING GPS';
        }

      case 'unavailable':
      default:
        switch (lang) {
          case NavLanguage.tamil:
            return 'ஜிபிஎஸ் கிடைக்கவில்லை';
          case NavLanguage.hindi:
            return 'जीपीएस अनुपलब्ध';
          case NavLanguage.telugu:
            return 'జీపీఎస్ అందుబాటులో లేదు';
          case NavLanguage.malayalam:
            return 'ജിപിഎസ് ലഭ്യമല്ല';
          case NavLanguage.kannada:
            return 'ಜಿಪಿಎಸ್ ಲಭ್ಯವಿಲ್ಲ';
          case NavLanguage.english:
            return 'GPS UNAVAILABLE';
        }
    }
  }

  static String getSharingBadge(NavLanguage lang) {
    switch (lang) {
      case NavLanguage.tamil:
        return 'பகிர்வு';
      case NavLanguage.hindi:
        return 'साझा';
      case NavLanguage.telugu:
        return 'షేరింగ్';
      case NavLanguage.malayalam:
        return 'പങ്കിടൽ';
      case NavLanguage.kannada:
        return 'ಹಂಚಿಕೆ';
      case NavLanguage.english:
        return 'SHARING';
    }
  }
}

/// A parsed step in an OSRM route.
class RouteStep {
  final String instruction;
  final String shortInstruction;
  final String maneuverType;
  final String? maneuverModifier;
  final LatLng location;
  final String roadName;
  final double distanceMeters;
  final double durationSeconds;
  final int? exitNumber;
  final IconData icon;

  const RouteStep({
    required this.instruction,
    required this.shortInstruction,
    required this.maneuverType,
    this.maneuverModifier,
    required this.location,
    required this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    this.exitNumber,
    required this.icon,
  });

  /// Localized instruction for this step in the given [NavLanguage].
  String localizedInstruction([NavLanguage lang = NavLanguage.english]) {
    if (lang == NavLanguage.english) return instruction;
    return NavigationLocalizer.buildInstructionAndIcon(
      type: maneuverType,
      modifier: maneuverModifier,
      roadName: roadName,
      exitNumber: exitNumber,
      lang: lang,
    ).instruction;
  }

  /// Localized short instruction for this step in the given [NavLanguage].
  String localizedShortInstruction([NavLanguage lang = NavLanguage.english]) {
    if (lang == NavLanguage.english) return shortInstruction;
    return NavigationLocalizer.buildInstructionAndIcon(
      type: maneuverType,
      modifier: maneuverModifier,
      roadName: roadName,
      exitNumber: exitNumber,
      lang: lang,
    ).shortInstruction;
  }

  factory RouteStep.fromOsrm(Map<String, dynamic> stepMap) {
    final maneuver = (stepMap['maneuver'] as Map<String, dynamic>?) ?? const {};
    final type = (maneuver['type'] as String?)?.toLowerCase().trim() ?? 'turn';
    final modifier = (maneuver['modifier'] as String?)?.toLowerCase().trim();
    final rawLoc = maneuver['location'] as List<dynamic>?;
    final location = (rawLoc != null && rawLoc.length >= 2)
        ? LatLng((rawLoc[1] as num).toDouble(), (rawLoc[0] as num).toDouble())
        : const LatLng(0, 0);

    final rawName = (stepMap['name'] as String?)?.trim() ?? '';
    final rawRef = (stepMap['ref'] as String?)?.trim() ?? '';
    final roadName = rawName.isNotEmpty
        ? rawName
        : (rawRef.isNotEmpty ? rawRef : '');

    final distanceMeters = (stepMap['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (stepMap['duration'] as num?)?.toDouble() ?? 0.0;
    final exitNumber = maneuver['exit'] as int?;

    final parsed = buildInstructionAndIcon(
      type: type,
      modifier: modifier,
      roadName: roadName,
      exitNumber: exitNumber,
    );

    return RouteStep(
      instruction: parsed.instruction,
      shortInstruction: parsed.shortInstruction,
      maneuverType: type,
      maneuverModifier: modifier,
      location: location,
      roadName: roadName,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      exitNumber: exitNumber,
      icon: parsed.icon,
    );
  }

  static ({String instruction, String shortInstruction, IconData icon})
      buildInstructionAndIcon({
    required String type,
    required String? modifier,
    required String roadName,
    required int? exitNumber,
    NavLanguage lang = NavLanguage.english,
  }) {
    return NavigationLocalizer.buildInstructionAndIcon(
      type: type,
      modifier: modifier,
      roadName: roadName,
      exitNumber: exitNumber,
      lang: lang,
    );
  }

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        'shortInstruction': shortInstruction,
        'maneuverType': maneuverType,
        'maneuverModifier': maneuverModifier,
        'lat': location.latitude,
        'lng': location.longitude,
        'roadName': roadName,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'exitNumber': exitNumber,
      };

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final parsed = buildInstructionAndIcon(
      type: json['maneuverType'] as String? ?? 'turn',
      modifier: json['maneuverModifier'] as String?,
      roadName: json['roadName'] as String? ?? '',
      exitNumber: json['exitNumber'] as int?,
    );
    return RouteStep(
      instruction: json['instruction'] as String? ?? parsed.instruction,
      shortInstruction: json['shortInstruction'] as String? ?? parsed.shortInstruction,
      maneuverType: json['maneuverType'] as String? ?? 'turn',
      maneuverModifier: json['maneuverModifier'] as String?,
      location: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      roadName: json['roadName'] as String? ?? '',
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      exitNumber: json['exitNumber'] as int?,
      icon: parsed.icon,
    );
  }
}

/// Holds state for live navigation visual instruction card and voice engine.
class NavigationInstructionState {
  final RouteStep? currentStep;
  final RouteStep? nextStep;
  final double? distanceToStepMeters;
  final bool isOffRoute;
  final double? offRouteDistanceMeters;
  final bool isDestinationReached;
  final String? voiceToSpeak;
  final int activeStepIndex;
  final int totalSteps;
  final NavLanguage language;
  final bool isVoiceUnavailable;

  const NavigationInstructionState({
    required this.currentStep,
    this.nextStep,
    required this.distanceToStepMeters,
    this.isOffRoute = false,
    this.offRouteDistanceMeters,
    this.isDestinationReached = false,
    this.voiceToSpeak,
    required this.activeStepIndex,
    required this.totalSteps,
    this.language = NavLanguage.english,
    this.isVoiceUnavailable = false,
  });

  static const empty = NavigationInstructionState(
    currentStep: null,
    nextStep: null,
    distanceToStepMeters: null,
    activeStepIndex: 0,
    totalSteps: 0,
    language: NavLanguage.english,
    isVoiceUnavailable: false,
  );
}

/// Core engine managing real-time GPS step tracking, announcement stages, and speech.
class NavigationInstructionEngine {
  List<RouteStep> _steps = const [];
  List<double> _stepCumulativeMeters = const [];
  double _totalRouteMeters = 0.0;

  int _currentStepIndex = 0;
  final Map<int, Set<AnnouncementStage>> _announcedStages = {};
  bool _voiceEnabled = true;
  NavLanguage _language = NavLanguage.english;
  bool _isVoiceUnavailable = false;
  String? _lastSpokenText;
  DateTime? _lastSpokenTime;

  NavigationInstructionEngine() {
    WebSpeechHelper.addVoicesChangedListener(_onVoicesChanged);
    _checkVoiceAvailability();
  }

  void _onVoicesChanged() {
    _checkVoiceAvailability();
  }

  void _checkVoiceAvailability() {
    if (WebSpeechHelper.isSupported) {
      _isVoiceUnavailable = !WebSpeechHelper.hasVoiceForLanguage(_language.bcp47);
    } else {
      _isVoiceUnavailable = false;
    }
  }

  bool get voiceEnabled => _voiceEnabled;
  NavLanguage get language => _language;
  bool get isVoiceUnavailable => _isVoiceUnavailable;
  int get currentStepIndex => _currentStepIndex;
  List<RouteStep> get steps => List.unmodifiable(_steps);

  void setVoiceEnabled(bool enabled) {
    _voiceEnabled = enabled;
    if (!enabled) {
      WebSpeechHelper.stop();
    }
  }

  void setLanguage(NavLanguage lang) {
    _language = lang;
    _checkVoiceAvailability();
  }

  /// Reset and initialize engine with a selected route and its parsed steps.
  void initializeRoute(List<RouteStep> routeSteps, double totalMeters) {
    _steps = List.from(routeSteps);
    _totalRouteMeters = totalMeters > 0 ? totalMeters : 0.0;
    _currentStepIndex = 0;
    _announcedStages.clear();
    _lastSpokenText = null;
    _lastSpokenTime = null;
    _checkVoiceAvailability();

    if (_steps.isEmpty) {
      _stepCumulativeMeters = const [];
      return;
    }

    // Precalculate cumulative distance to each step maneuver
    final cumulative = <double>[0.0];
    var acc = 0.0;
    for (var i = 0; i < _steps.length - 1; i++) {
      acc += _steps[i].distanceMeters;
      cumulative.add(acc);
    }
    _stepCumulativeMeters = cumulative;
  }

  /// Process new GPS fix and update step progression + voice announcement.
  NavigationInstructionState updateGpsPosition({
    required LatLng userPosition,
    required double userProgressMeters,
    double? gpsAccuracyMeters,
    bool isStaleGps = false,
    bool isOffRoute = false,
    double? offRouteMeters,
    bool isNavigationActive = true,
  }) {
    if (!isNavigationActive) {
      WebSpeechHelper.stop();
      return NavigationInstructionState.empty;
    }

    // Fallback when no OSRM steps are available
    if (_steps.isEmpty) {
      final remaining = math.max(0.0, _totalRouteMeters - userProgressMeters);
      final reached = remaining <= 35.0 && _totalRouteMeters > 0;
      return NavigationInstructionState(
        currentStep: RouteStep(
          instruction: reached ? 'Arrive at destination' : 'Follow the highlighted route',
          shortInstruction: reached ? 'Arrive' : 'Continue',
          maneuverType: reached ? 'arrive' : 'continue',
          location: userPosition,
          roadName: '',
          distanceMeters: remaining,
          durationSeconds: remaining / 12.0,
          icon: reached ? Icons.place_rounded : Icons.navigation_rounded,
        ),
        nextStep: null,
        distanceToStepMeters: remaining,
        isOffRoute: isOffRoute,
        offRouteDistanceMeters: offRouteMeters,
        isDestinationReached: reached,
        voiceToSpeak: null,
        activeStepIndex: 0,
        totalSteps: 0,
        language: _language,
        isVoiceUnavailable: _isVoiceUnavailable,
      );
    }

    // 1. Advance step index if user has progressed past the upcoming manoeuvre location
    while (_currentStepIndex < _steps.length - 1) {
      final nextStepProgress = (_currentStepIndex + 1 < _stepCumulativeMeters.length)
          ? _stepCumulativeMeters[_currentStepIndex + 1]
          : _totalRouteMeters;

      // 25m buffer past maneuver point before advancing to next step
      if (userProgressMeters > nextStepProgress + 25.0) {
        _currentStepIndex++;
      } else {
        break;
      }
    }

    final int targetManeuverIndex = (_currentStepIndex + 1 < _steps.length)
        ? _currentStepIndex + 1
        : _currentStepIndex;

    final targetStep = _steps[targetManeuverIndex];
    final nextUpcomingStep = (targetManeuverIndex + 1 < _steps.length)
        ? _steps[targetManeuverIndex + 1]
        : null;

    final targetProgressMeters = (targetManeuverIndex < _stepCumulativeMeters.length)
        ? _stepCumulativeMeters[targetManeuverIndex]
        : _totalRouteMeters;

    final distanceToManeuver = math.max(
      0.0,
      targetProgressManeuverDistance(targetProgressMeters, userProgressMeters),
    );

    final isArrival = targetStep.maneuverType == 'arrive' ||
        (_currentStepIndex == _steps.length - 1);
    final isReached = isArrival && distanceToManeuver <= 35.0;

    // 2. Check announcement trigger stage
    String? announcementToSpeak;
    final canAnnounce = !isOffRoute &&
        !isStaleGps &&
        (gpsAccuracyMeters == null || gpsAccuracyMeters <= 65.0);

    if (canAnnounce && !isReached) {
      final stage = evaluateAnnouncementStage(
        distanceToManeuverMeters: distanceToManeuver,
        stepTotalDistanceMeters: targetStep.distanceMeters,
        isArrival: isArrival,
      );

      if (stage != AnnouncementStage.none) {
        final stepAnnounced = _announcedStages.putIfAbsent(
          targetManeuverIndex,
          () => <AnnouncementStage>{},
        );

        if (!stepAnnounced.contains(stage)) {
          stepAnnounced.add(stage);
          final text = generateVoiceAnnouncement(targetStep, stage, distanceToManeuver);
          if (_voiceEnabled) {
            announcementToSpeak = text;
            _dispatchVoice(text);
          }
        }
      }
    } else if (isReached) {
      final stepAnnounced = _announcedStages.putIfAbsent(
        targetManeuverIndex,
        () => <AnnouncementStage>{},
      );
      if (!stepAnnounced.contains(AnnouncementStage.stageArrived)) {
        stepAnnounced.add(AnnouncementStage.stageArrived);
        final text = NavigationLocalizer.getDestinationArrivalAnnouncement(_language);
        if (_voiceEnabled) {
          announcementToSpeak = text;
          _dispatchVoice(text);
        }
      }
    }

    return NavigationInstructionState(
      currentStep: targetStep,
      nextStep: nextUpcomingStep,
      distanceToStepMeters: distanceToManeuver,
      isOffRoute: isOffRoute,
      offRouteDistanceMeters: offRouteMeters,
      isDestinationReached: isReached,
      voiceToSpeak: announcementToSpeak,
      activeStepIndex: targetManeuverIndex,
      totalSteps: _steps.length,
      language: _language,
      isVoiceUnavailable: _isVoiceUnavailable,
    );
  }

  /// Calculates route progress distance to manoeuvre.
  double targetProgressManeuverDistance(double targetMeters, double userMeters) {
    return targetMeters - userMeters;
  }

  /// Determine which announcement stage is applicable based on distance and step length.
  AnnouncementStage evaluateAnnouncementStage({
    required double distanceToManeuverMeters,
    required double stepTotalDistanceMeters,
    required bool isArrival,
  }) {
    if (distanceToManeuverMeters <= 35.0) {
      return AnnouncementStage.stageNow;
    }

    // 150m stage (100m to 180m): valid if step is at least 110m long
    if (distanceToManeuverMeters <= 180.0 && distanceToManeuverMeters >= 45.0) {
      if (stepTotalDistanceMeters >= 110.0 || isArrival) {
        return AnnouncementStage.stage150m;
      }
    }

    // 500m stage (400m to 550m): valid if step is at least 320m long
    if (distanceToManeuverMeters <= 550.0 && distanceToManeuverMeters >= 220.0) {
      if (stepTotalDistanceMeters >= 320.0 || isArrival) {
        return AnnouncementStage.stage500m;
      }
    }

    return AnnouncementStage.none;
  }

  /// Formulate user-friendly speech text from the step and stage in the active language.
  String generateVoiceAnnouncement(
    RouteStep step,
    AnnouncementStage stage,
    double distanceMeters,
  ) {
    return NavigationLocalizer.generateVoiceAnnouncement(
      step: step,
      stage: stage,
      distanceMeters: distanceMeters,
      lang: _language,
    );
  }

  void _dispatchVoice(String message) {
    final now = DateTime.now();
    if (_lastSpokenText == message &&
        _lastSpokenTime != null &&
        now.difference(_lastSpokenTime!).inSeconds < 10) {
      return;
    }
    _lastSpokenText = message;
    _lastSpokenTime = now;
    final spoke = WebSpeechHelper.speak(message, lang: _language.bcp47);
    if (!spoke && WebSpeechHelper.isSupported) {
      _isVoiceUnavailable = true;
    }
  }

  void stop() {
    WebSpeechHelper.stop();
  }

  /// Format distance for UI display (e.g., '250 m', '1.4 km').
  static String formatDistance(double? meters) {
    if (meters == null || meters <= 0) return '0 m';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

/// A Google Maps-style prominent turn-by-turn navigation card with multilingual support.
class NavigationInstructionCard extends StatelessWidget {
  final RouteStep? currentStep;
  final RouteStep? nextStep;
  final double? distanceToStepMeters;
  final bool isOffRoute;
  final double? offRouteDistanceMeters;
  final bool isDestinationReached;
  final bool isVoiceEnabled;
  final VoidCallback onToggleVoice;
  final bool isDarkMode;
  final NavLanguage language;
  final ValueChanged<NavLanguage>? onSelectLanguage;
  final bool isVoiceUnavailable;

  const NavigationInstructionCard({
    super.key,
    required this.currentStep,
    this.nextStep,
    required this.distanceToStepMeters,
    this.isOffRoute = false,
    this.offRouteDistanceMeters,
    this.isDestinationReached = false,
    required this.isVoiceEnabled,
    required this.onToggleVoice,
    required this.isDarkMode,
    this.language = NavLanguage.english,
    this.onSelectLanguage,
    this.isVoiceUnavailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final distStr = NavigationInstructionEngine.formatDistance(distanceToStepMeters);

    final Color statusColor = isOffRoute
        ? const Color(0xffEF4444)
        : (isDestinationReached ? const Color(0xff10B981) : const Color(0xff00D9FF));

    final IconData mainIcon = isOffRoute
        ? Icons.warning_rounded
        : (isDestinationReached
            ? Icons.check_circle_rounded
            : (currentStep?.icon ?? Icons.straight_rounded));

    final String mainInstruction = NavigationLocalizer.getMainInstruction(
      currentStep: currentStep,
      isOffRoute: isOffRoute,
      isDestinationReached: isDestinationReached,
      lang: language,
    );

    final String subDetails = NavigationLocalizer.getSubDetails(
      currentStep: currentStep,
      isOffRoute: isOffRoute,
      offRouteDistanceMeters: offRouteDistanceMeters,
      isDestinationReached: isDestinationReached,
      lang: language,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey('${currentStep?.instruction}_${isOffRoute}_${isDestinationReached}_${language.code}'),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xf0061224)
              : Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode
                ? statusColor.withValues(alpha: 0.5)
                : statusColor.withValues(alpha: 0.8),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: isDarkMode ? 0.22 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Primary Instruction Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Maneuver Icon Disc
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOffRoute
                            ? const [Color(0xffEF4444), Color(0xff991B1B)]
                            : (isDestinationReached
                                ? const [Color(0xff10B981), Color(0xff065F46)]
                                : const [Color(0xff00D9FF), Color(0xff2563EB)]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(mainIcon, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Middle: Distance & Instruction Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (!isOffRoute && !isDestinationReached) ...[
                              Text(
                                distStr,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isDarkMode
                                      ? const Color(0xff00D9FF)
                                      : const Color(0xff1D4ED8),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                mainInstruction,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isOffRoute
                                      ? const Color(0xffEF4444)
                                      : (isDestinationReached
                                          ? const Color(0xff10B981)
                                          : (isDarkMode
                                              ? Colors.white
                                              : const Color(0xff0F172A))),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subDetails,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isOffRoute
                                ? const Color(0xffEF4444)
                                : (isDarkMode
                                    ? Colors.white70
                                    : const Color(0xff475569)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Language Selector Pill
                  PopupMenuButton<NavLanguage>(
                    tooltip: 'Navigation Language (${language.displayName})',
                    initialValue: language,
                    onSelected: (NavLanguage selected) {
                      onSelectLanguage?.call(selected);
                    },
                    offset: const Offset(0, 38),
                    color: isDarkMode ? const Color(0xff081B35) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDarkMode
                            ? const Color(0xff00D9FF).withValues(alpha: 0.35)
                            : const Color(0xffCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    itemBuilder: (context) => NavLanguage.values.map((lang) {
                      final isSelected = lang == language;
                      return PopupMenuItem<NavLanguage>(
                        value: lang,
                        height: 38,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xff00D9FF).withValues(alpha: 0.22)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xff00D9FF)
                                      : Colors.grey.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                lang.shortCode,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? const Color(0xff00D9FF)
                                      : (isDarkMode ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${lang.displayName} (${lang.englishName})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xff00D9FF)
                                      : (isDarkMode ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded, size: 16, color: Color(0xff00D9FF)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isVoiceUnavailable && isVoiceEnabled
                              ? const Color(0xffF59E0B)
                              : (isDarkMode ? Colors.white24 : Colors.black12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            language.shortCode,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isVoiceUnavailable && isVoiceEnabled
                                  ? const Color(0xffF59E0B)
                                  : (isDarkMode ? const Color(0xff00D9FF) : const Color(0xff1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 15,
                            color: isVoiceUnavailable && isVoiceEnabled
                                ? const Color(0xffF59E0B)
                                : (isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Voice Guidance Quick Toggle Button
                  Tooltip(
                    message: isVoiceEnabled
                        ? 'Voice guidance ON (Click to mute)'
                        : 'Voice guidance MUTED (Click to unmute)',
                    child: InkWell(
                      onTap: onToggleVoice,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isVoiceEnabled
                              ? const Color(0xff00D9FF).withValues(alpha: 0.16)
                              : (isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          border: Border.all(
                            color: isVoiceEnabled
                                ? const Color(0xff00D9FF).withValues(alpha: 0.5)
                                : (isDarkMode ? Colors.white24 : Colors.black12),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isVoiceEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 18,
                          color: isVoiceEnabled
                              ? const Color(0xff00D9FF)
                              : (isDarkMode ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Voice unavailable advisory pill (if requested language voice is missing from browser)
            if (isVoiceUnavailable && isVoiceEnabled) ...[
              Container(
                margin: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xffF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xffF59E0B).withValues(alpha: 0.40),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xffF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        NavigationLocalizer.getVoiceUnavailableMessage(language),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xffF59E0B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Upcoming Next Manoeuvre Sub-strip
            if (nextStep != null && !isOffRoute && !isDestinationReached) ...[
              Container(
                height: 1,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xff081B35).withValues(alpha: 0.65)
                      : const Color(0xffF8FAFC),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      nextStep!.icon,
                      size: 15,
                      color: isDarkMode ? const Color(0xff00D9FF) : const Color(0xff2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${NavigationLocalizer.getThenPrefix(language)}${nextStep!.localizedShortInstruction(language)}${nextStep!.roadName.isNotEmpty ? ' onto ${nextStep!.roadName}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : const Color(0xff475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (nextStep!.distanceMeters > 0)
                      Text(
                        NavigationInstructionEngine.formatDistance(nextStep!.distanceMeters),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? const Color(0xff00D9FF).withValues(alpha: 0.8)
                              : const Color(0xff2563EB),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
