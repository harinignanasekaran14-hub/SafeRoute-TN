import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

// ============================================================================
// EMERGENCY CONTACT MODEL & STORAGE (LOCAL ONLY)
// ============================================================================

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'created_at': createdAt.toIso8601String(),
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String? ?? UniqueKey().toString(),
        name: json['name'] as String? ?? 'Contact',
        phone: json['phone'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class EmergencyContactsStorage {
  static const String storageKey = 'saferoute_emergency_contacts';

  static Future<List<EmergencyContact>> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(storageKey);
      if (rawList == null) return [];
      final List<EmergencyContact> contacts = [];
      for (final item in rawList) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          contacts.add(EmergencyContact.fromJson(decoded));
        } catch (_) {}
      }
      return contacts;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> saveContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = contacts.map((c) => jsonEncode(c.toJson())).toList();
      return await prefs.setStringList(storageKey, encoded);
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// EMERGENCY LOCALIZATION (ENGLISH & TAMIL)
// ============================================================================

class EmergencyAssistanceLocalization {
  static String title(bool isTamil) =>
      isTamil ? 'அவசர உதவி' : 'Emergency Assistance';

  static String subtitle(bool isTamil) => isTamil
      ? 'அவசர சேவைகளை விரைவாக அணுகவும்'
      : 'Quick access to emergency services';

  static String quickSos(bool isTamil) => isTamil ? 'விரைவு SOS' : 'Quick SOS';

  static String quickSosSubtitle(bool isTamil) => isTamil
      ? 'அழைக்க ஒரு அவசர சேவையைத் தேர்வு செய்யவும்'
      : 'Choose an emergency service to continue.';

  static String police(bool isTamil) => isTamil ? 'காவல்துறை' : 'Police';

  static String policeDesc(bool isTamil) => isTamil
      ? 'அவசர சட்டம் & ஒழுங்கு மற்றும் பாதுகாப்பு உதவி'
      : 'Law enforcement & immediate crime or safety response';

  static String ambulance(bool isTamil) => isTamil ? 'ஆம்புலன்ஸ்' : 'Ambulance';

  static String ambulanceDesc(bool isTamil) => isTamil
      ? 'தமிழ்நாடு மருத்துவ அவசர ஆம்புலன்ஸ் சேவை'
      : 'Medical emergencies & patient transit response';

  static String fire(bool isTamil) =>
      isTamil ? 'தீயணைப்பு & மீட்பு' : 'Fire & Rescue';

  static String fireDesc(bool isTamil) => isTamil
      ? 'தீ விபத்து, பேரிடர் மற்றும் மீட்பு பணிகள்'
      : 'Fire accidents, disaster rescue & hazardous situations';

  static String hospital(bool isTamil) =>
      isTamil ? 'அருகிலுள்ள மருத்துவமனை' : 'Nearby Hospital';

  static String hospitalUnavailable(bool isTamil) => isTamil
      ? 'அருகிலுள்ள மருத்துவமனை தகவல் தற்போது கிடைக்கவில்லை.'
      : 'Nearby hospital information is currently unavailable.';

  static String nearbyPoliceStation(bool isTamil) =>
      isTamil ? 'அருகிலுள்ள காவல் நிலையம்' : 'Nearby Police Station';

  static String policeUnavailable(bool isTamil) => isTamil
      ? 'அருகிலுள்ள காவல் நிலைய தகவல் தற்போது கிடைக்கவில்லை.'
      : 'Nearby police station information is currently unavailable.';

  static String locationSharingTitle(bool isTamil) =>
      isTamil ? 'அவசர இருப்பிடப் பகிர்வு' : 'Emergency Location Sharing';

  static String locationSharingSubtitle(bool isTamil) => isTamil
      ? 'உடனடி உதவி பெற உங்கள் தற்போதைய GPS இருப்பிடத்தை பகிரவும்'
      : 'Share your exact GPS coordinates snapshot for immediate assistance';

  static String shareWhatsApp(bool isTamil) =>
      isTamil ? 'WhatsApp-ல் பகிர்' : 'Share via WhatsApp';

  static String shareSms(bool isTamil) =>
      isTamil ? 'SMS-ல் பகிர்' : 'Share via SMS';

  static String copyLink(bool isTamil) =>
      isTamil ? 'இணைப்பை நகலெடு' : 'Copy Location Link';

  static String copyMessage(bool isTamil) =>
      isTamil ? 'செய்தியை நகலெடு' : 'Copy Emergency Message';

  static String gpsUnavailable(bool isTamil) => isTamil
      ? 'GPS இருப்பிடம் கிடைக்கவில்லை. உலாவி இருப்பிட அனுமதியை சரிபார்க்கவும்.'
      : 'GPS location unavailable. Please enable browser location permissions.';

  static String snapshotNotice(bool isTamil) => isTamil
      ? 'நேரலை கண்காணிப்பு அல்ல · உடனடி GPS பதிவு'
      : 'Instantaneous GPS snapshot · Not continuous live tracking';

  static String call(bool isTamil) => isTamil ? 'அழை' : 'Call';

  static String cancel(bool isTamil) => isTamil ? 'ரத்து' : 'Cancel';

  static String callConfirmTitle(String service, bool isTamil) =>
      isTamil ? '$service-ஐ அழைக்கவா?' : 'Call $service?';

  static String callConfirmPrompt(String number, bool isTamil) => isTamil
      ? '$number எண்ணை அழைக்க விரும்புகிறீர்களா?'
      : 'Do you want to call $number?';

  static String callDisclaimer(bool isTamil) => isTamil
      ? 'SafeRoute TN உங்கள் சாதனத்தின் தொலைபேசி டயலரைத் திறக்கிறது. அவசர சேவைகள் தானாக அனுப்பப்படாது.'
      : 'SafeRoute TN opens your device\'s dialer. Emergency units are not automatically dispatched.';

  static String currentRouteHeading(bool isTamil) =>
      isTamil ? 'உங்கள் தற்போதைய வழி' : 'Your Current Route';

  static String noRouteHeading(bool isTamil) =>
      isTamil ? 'செயலில் உள்ள வழி இல்லை' : 'No active route';

  static String noRoutePrompt(bool isTamil) => isTamil
      ? 'வழி தொடர்பான அவசர சூழலைக் காண ஒரு வழியைத் திட்டமிடுங்கள்.'
      : 'Plan a route to see route-specific emergency context.';

  static String safetyContextHeading(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு சூழல்' : 'Safety context';

  static String emergencyContactsHeading(bool isTamil) =>
      isTamil ? 'அவசர தொடர்புகள் (உள்ளூர்)' : 'Emergency Contacts';

  static String addContact(bool isTamil) =>
      isTamil ? 'தொடர்பைச் சேர்' : 'Add Contact';

  static String contactNameHint(bool isTamil) =>
      isTamil ? 'பெயர் (உதா: குடும்பம்)' : 'Contact Name (e.g. Family)';

  static String contactPhoneHint(bool isTamil) =>
      isTamil ? 'தொலைபேசி எண்' : 'Phone Number';

  static String save(bool isTamil) => isTamil ? 'சேமி' : 'Save';

  static String delete(bool isTamil) => isTamil ? 'நீக்கு' : 'Delete';

  static String deleteContactPrompt(String name, bool isTamil) =>
      isTamil ? '$name தொடர்பை நீக்கவா?' : 'Delete contact "$name"?';

  static String noContactsSaved(bool isTamil) => isTamil
      ? 'சேமிக்கப்பட்ட அவசர தொடர்புகள் இல்லை'
      : 'No emergency contacts saved yet';

  static String privacyNote(bool isTamil) => isTamil
      ? 'தனியுரிமை: தொடர்புகள் உங்கள் உலாவியில் மட்டுமே சேமிக்கப்படுகின்றன. சர்வர்க்கு அனுப்பப்படாது.'
      : 'Privacy: Contacts stored locally on your device only. Never sent to any server.';

  static String close(bool isTamil) => isTamil ? 'முடிந்தது' : 'Done';
}

// ============================================================================
// EMERGENCY CALL ACTION SERVICE
// ============================================================================

class EmergencyCallService {
  static Future<void> initiateCallWithConfirmation({
    required BuildContext context,
    required String serviceName,
    required String phoneNumber,
    required bool isTamil,
    required bool isDarkMode,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dlgContext) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? NeonTheme.cardDark
              : NeonTheme.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: NeonTheme.dangerRed.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: NeonTheme.dangerRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: NeonTheme.dangerRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  EmergencyAssistanceLocalization.callConfirmTitle(
                    serviceName,
                    isTamil,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                EmergencyAssistanceLocalization.callConfirmPrompt(
                  phoneNumber,
                  isTamil,
                ),
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDarkMode
                      ? NeonTheme.textPrimaryDark
                      : NeonTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: NeonTheme.warningGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        EmergencyAssistanceLocalization.callDisclaimer(isTamil),
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          color: isDarkMode
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgContext).pop(false),
              child: Text(
                EmergencyAssistanceLocalization.cancel(isTamil),
                style: TextStyle(
                  color: isDarkMode
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dlgContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonTheme.dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                EmergencyAssistanceLocalization.call(isTamil),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$clean');
      try {
        final launched = await launchUrl(uri);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTamil
                    ? 'டயலரைத் திறக்க முடியவில்லை. $phoneNumber எண்ணை நேரடியாக டயல் செய்யவும்.'
                    : 'Unable to open dialer. Please dial $phoneNumber directly on your phone.',
              ),
              backgroundColor: NeonTheme.warningGold,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTamil
                    ? 'டயலரைத் தொடங்க முடியவில்லை. $phoneNumber எண்ணை நேரடியாக டயல் செய்யவும்.'
                    : 'Could not open phone dialer on this device. Please call $phoneNumber directly.',
              ),
              backgroundColor: NeonTheme.warningGold,
            ),
          );
        }
      }
    }
  }

  static Future<bool> launchExternalUri(
    BuildContext context,
    Uri uri, {
    String? failureFallback,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted && failureFallback != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureFallback),
            backgroundColor: NeonTheme.warningGold,
          ),
        );
      }
      return launched;
    } catch (_) {
      if (context.mounted && failureFallback != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureFallback),
            backgroundColor: NeonTheme.warningGold,
          ),
        );
      }
      return false;
    }
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    String text,
    String successMessage,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: NeonTheme.safeGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ============================================================================
// EMERGENCY LOCATION SHARING HELPER
// ============================================================================

class EmergencyLocationHelper {
  static bool isValidCoordinate(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (!lat.isFinite || !lon.isFinite) return false;
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  static String buildGoogleMapsUrl(double latitude, double longitude) {
    if (!isValidCoordinate(latitude, longitude)) return '';
    return 'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  static String buildSosMessage({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String? routeOrigin,
    String? routeDestination,
    DateTime? timestamp,
  }) {
    if (!isValidCoordinate(latitude, longitude)) {
      return 'Emergency SOS – SafeRoute TN: Location unavailable.';
    }
    final buffer = StringBuffer();
    buffer.writeln('Emergency SOS – SafeRoute TN');
    buffer.writeln('I need immediate assistance! Here is my current location:');
    buffer.writeln(buildGoogleMapsUrl(latitude, longitude));
    buffer.write(
      'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    );
    if (accuracyMeters != null &&
        accuracyMeters > 0 &&
        accuracyMeters.isFinite) {
      buffer.write(' (±${accuracyMeters.round()}m accuracy)');
    }
    buffer.writeln();

    final hasOrigin = routeOrigin != null && routeOrigin.trim().isNotEmpty;
    final hasDest =
        routeDestination != null && routeDestination.trim().isNotEmpty;
    if (hasOrigin && hasDest) {
      buffer.writeln(
        'Route: ${routeOrigin.trim()} → ${routeDestination.trim()}',
      );
    } else if (hasDest) {
      buffer.writeln('Destination: ${routeDestination.trim()}');
    } else if (hasOrigin) {
      buffer.writeln('Origin: ${routeOrigin.trim()}');
    }

    final ts = timestamp ?? DateTime.now();
    buffer.write(
      '(Snapshot taken at ${ts.toLocal().toString().split('.')[0]} · Not continuous live tracking)',
    );
    return buffer.toString();
  }

  static Uri buildWhatsAppUri(String message, {String? phoneNumber}) {
    final cleanPhone = phoneNumber?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    final encoded = Uri.encodeComponent(message);
    if (cleanPhone.isNotEmpty) {
      return Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    }
    return Uri.parse('https://wa.me/?text=$encoded');
  }

  static Uri buildSmsUri(String message, {String? phoneNumber}) {
    final cleanPhone = phoneNumber?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
    final encoded = Uri.encodeComponent(message);
    if (cleanPhone.isNotEmpty) {
      return Uri.parse('sms:$cleanPhone?body=$encoded');
    }
    return Uri.parse('sms:?body=$encoded');
  }
}

// ============================================================================
// EMERGENCY ASSISTANCE DIALOG WIDGET
// ============================================================================

class EmergencyAssistanceDialog extends StatefulWidget {
  final bool isDarkMode;
  final String? routeOrigin;
  final String? routeDestination;
  final String? vehicleMode;
  final String? travelTimeMode;
  final double? distanceKm;
  final double? durationMinutes;
  final double? safetyScore;
  final PersonalizedSafetyResult? personalizedSafetyResult;
  final List<Facility>? nearbyFacilities;
  final String Function(double minutes) formatDurationFn;
  final VoidCallback? onOpenNearbyPlaces;
  final Position? currentPosition;
  final Future<Position?> Function()? onRefreshLocation;

  const EmergencyAssistanceDialog({
    super.key,
    required this.isDarkMode,
    this.routeOrigin,
    this.routeDestination,
    this.vehicleMode,
    this.travelTimeMode,
    this.distanceKm,
    this.durationMinutes,
    this.safetyScore,
    this.personalizedSafetyResult,
    this.nearbyFacilities,
    required this.formatDurationFn,
    this.onOpenNearbyPlaces,
    this.currentPosition,
    this.onRefreshLocation,
  });

  @override
  State<EmergencyAssistanceDialog> createState() =>
      _EmergencyAssistanceDialogState();
}

class _EmergencyAssistanceDialogState extends State<EmergencyAssistanceDialog> {
  bool _isTamil = false;
  List<EmergencyContact> _contacts = [];
  bool _contactsLoaded = false;
  bool _showAddContactForm = false;
  Position? _activePosition;
  bool _isRefreshingLocation = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activePosition = widget.currentPosition;
    _loadContacts();
  }

  @override
  void didUpdateWidget(EmergencyAssistanceDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
      _activePosition = widget.currentPosition;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final list = await EmergencyContactsStorage.loadContacts();
    if (mounted) {
      setState(() {
        _contacts = list;
        _contactsLoaded = true;
      });
    }
  }

  Future<void> _addContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    final newContact = EmergencyContact(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      createdAt: DateTime.now(),
    );

    final updated = [newContact, ..._contacts];
    await EmergencyContactsStorage.saveContacts(updated);
    if (mounted) {
      setState(() {
        _contacts = updated;
        _showAddContactForm = false;
        _nameController.clear();
        _phoneController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTamil
                ? '✓ தொடர்பு சேமிக்கப்பட்டது'
                : '✓ Emergency contact saved',
          ),
          backgroundColor: NeonTheme.safeGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? NeonTheme.cardDark
            : NeonTheme.cardLight,
        title: Text(
          EmergencyAssistanceLocalization.delete(_isTamil),
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          EmergencyAssistanceLocalization.deleteContactPrompt(
            contact.name,
            _isTamil,
          ),
          style: TextStyle(
            color: widget.isDarkMode
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(false),
            child: Text(EmergencyAssistanceLocalization.cancel(_isTamil)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dlgContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: Text(EmergencyAssistanceLocalization.delete(_isTamil)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = _contacts.where((c) => c.id != contact.id).toList();
      await EmergencyContactsStorage.saveContacts(updated);
      if (mounted) {
        setState(() {
          _contacts = updated;
        });
      }
    }
  }

  Future<void> _refreshLocation() async {
    if (widget.onRefreshLocation == null) return;
    setState(() => _isRefreshingLocation = true);
    try {
      final pos = await widget.onRefreshLocation!();
      if (mounted) {
        setState(() {
          _activePosition = pos;
          _isRefreshingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRefreshingLocation = false);
      }
    }
  }

  Facility? _findNearestHospital() {
    final list = widget.nearbyFacilities;
    if (list == null || list.isEmpty) return null;
    final hospitals = list.where((f) => f.categoryId == 'hospital').toList();
    if (hospitals.isEmpty) return null;
    final pos = _activePosition;
    if (pos != null &&
        EmergencyLocationHelper.isValidCoordinate(pos.latitude, pos.longitude)) {
      hospitals.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          a.lat,
          a.lon,
        );
        final distB = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          b.lat,
          b.lon,
        );
        return distA.compareTo(distB);
      });
    }
    return hospitals.first;
  }

  Facility? _findNearestPoliceStation() {
    final list = widget.nearbyFacilities;
    if (list == null || list.isEmpty) return null;
    final stations = list.where((f) => f.categoryId == 'police').toList();
    if (stations.isEmpty) return null;
    final pos = _activePosition;
    if (pos != null &&
        EmergencyLocationHelper.isValidCoordinate(pos.latitude, pos.longitude)) {
      stations.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          a.lat,
          a.lon,
        );
        final distB = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          b.lat,
          b.lon,
        );
        return distA.compareTo(distB);
      });
    }
    return stations.first;
  }

  Future<void> _shareViaWhatsApp(String message, {String? phoneNumber}) async {
    final uri = EmergencyLocationHelper.buildWhatsAppUri(
      message,
      phoneNumber: phoneNumber,
    );
    final launched = await EmergencyCallService.launchExternalUri(
      context,
      uri,
      failureFallback: _isTamil
          ? 'WhatsApp திறக்க முடியவில்லை. செய்தி கிளிப்போர்டில் நகலெடுக்கப்பட்டது.'
          : 'Unable to launch WhatsApp. Message copied to clipboard instead.',
    );
    if (!launched && mounted) {
      await EmergencyCallService.copyToClipboard(
        context,
        message,
        _isTamil ? '✓ செய்தி நகலெடுக்கப்பட்டது' : '✓ Message copied to clipboard',
      );
    }
  }

  Future<void> _shareViaSms(String message, {String? phoneNumber}) async {
    final uri = EmergencyLocationHelper.buildSmsUri(
      message,
      phoneNumber: phoneNumber,
    );
    final launched = await EmergencyCallService.launchExternalUri(
      context,
      uri,
      failureFallback: _isTamil
          ? 'SMS திறக்க முடியவில்லை. செய்தி கிளிப்போர்டில் நகலெடுக்கப்பட்டது.'
          : 'Unable to launch SMS. Message copied to clipboard instead.',
    );
    if (!launched && mounted) {
      await EmergencyCallService.copyToClipboard(
        context,
        message,
        _isTamil ? '✓ செய்தி நகலெடுக்கப்பட்டது' : '✓ Message copied to clipboard',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 640;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: media.size.height * 0.94,
        ),
        decoration: BoxDecoration(
          color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: NeonTheme.dangerRed.withValues(alpha: 0.55),
            width: 1.4,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: NeonTheme.dangerRed.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : NeonTheme.cardShadow(isDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildDialogHeader(isDark),
            // Body Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick SOS Section
                    _buildQuickSosSection(isDark),
                    const SizedBox(height: 14),
                    // Emergency Location Sharing Section
                    _buildLocationSharingSection(isDark, isMobile),
                    const SizedBox(height: 14),
                    // Main Emergency Services (Police, Ambulance, Fire, Hospital)
                    _buildEmergencyServicesSection(isDark, isMobile),
                    const SizedBox(height: 14),
                    // Current Route Context
                    _buildRouteContextSection(isDark),
                    const SizedBox(height: 14),
                    // Route Safety Factor Context (if route is loaded)
                    if (widget.personalizedSafetyResult != null) ...[
                      _buildSafetyFactorsContext(isDark),
                      const SizedBox(height: 14),
                    ],
                    // Saved Local Emergency Contacts
                    _buildEmergencyContactsSection(isDark),
                    const SizedBox(height: 14),
                    // Disclaimer banner
                    _buildSafetyDisclaimer(isDark),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Footer
            _buildDialogFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffDC2626), Color(0xff991B1B)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: NeonTheme.dangerRed.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text('🚨', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EmergencyAssistanceLocalization.title(_isTamil),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
                Text(
                  EmergencyAssistanceLocalization.subtitle(_isTamil),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // Language Switcher
          InkWell(
            onTap: () {
              setState(() {
                _isTamil = !_isTamil;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isTamil
                    ? NeonTheme.neonAmber.withValues(alpha: 0.2)
                    : NeonTheme.neonCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isTamil ? NeonTheme.neonAmber : NeonTheme.neonCyan,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 12,
                    color: _isTamil ? NeonTheme.neonAmber : NeonTheme.neonCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isTamil ? 'தமிழ்' : 'English',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _isTamil
                          ? NeonTheme.neonAmber
                          : NeonTheme.neonCyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSosSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: NeonTheme.dangerRed.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: NeonTheme.dangerRed,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                EmergencyAssistanceLocalization.quickSos(_isTamil),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: NeonTheme.dangerRed,
                ),
              ),
              const Spacer(),
              Text(
                EmergencyAssistanceLocalization.quickSosSubtitle(_isTamil),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildQuickSosButton(
                  title: 'Police',
                  number: '112',
                  icon: Icons.local_police_rounded,
                  color: const Color(0xff3B82F6),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickSosButton(
                  title: 'Ambulance',
                  number: '108',
                  icon: Icons.medical_services_rounded,
                  color: const Color(0xff10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickSosButton(
                  title: 'Fire',
                  number: '101',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xffF97316),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSosButton({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          EmergencyCallService.initiateCallWithConfirmation(
            context: context,
            serviceName: title,
            phoneNumber: number,
            isTamil: _isTamil,
            isDarkMode: widget.isDarkMode,
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                number,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSharingSection(bool isDark, bool isMobile) {
    final pos = _activePosition;
    final hasValidGps = pos != null &&
        EmergencyLocationHelper.isValidCoordinate(pos.latitude, pos.longitude);

    final lat = pos?.latitude;
    final lon = pos?.longitude;
    final accuracy = pos?.accuracy;
    final mapUrl = hasValidGps
        ? EmergencyLocationHelper.buildGoogleMapsUrl(lat!, lon!)
        : null;
    final sosMessage = hasValidGps
        ? EmergencyLocationHelper.buildSosMessage(
            latitude: lat!,
            longitude: lon!,
            accuracyMeters: accuracy,
            routeOrigin: widget.routeOrigin,
            routeDestination: widget.routeDestination,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff0C1A30) : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValidGps
              ? const Color(0xff00E5A8).withValues(alpha: 0.5)
              : const Color(0xffFFB020).withValues(alpha: 0.5),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (hasValidGps
                          ? const Color(0xff00E5A8)
                          : const Color(0xffFFB020))
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.share_location_rounded,
                  color: hasValidGps
                      ? const Color(0xff00E5A8)
                      : const Color(0xffFFB020),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EmergencyAssistanceLocalization.locationSharingTitle(
                        _isTamil,
                      ),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xff0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      EmergencyAssistanceLocalization.snapshotNotice(_isTamil),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : const Color(0xff64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshingLocation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (widget.onRefreshLocation != null)
                IconButton(
                  tooltip: _isTamil ? 'இருப்பிடத்தைப் புதுப்பி' : 'Refresh Location',
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  color: hasValidGps
                      ? const Color(0xff00E5A8)
                      : const Color(0xffFFB020),
                  onPressed: _refreshLocation,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasValidGps) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff07101E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xffE2E8F0),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: Color(0xffFF5252),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}'
                      '${accuracy != null && accuracy > 0 ? ' (±${accuracy.round()}m)' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xff1E293B),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _shareViaWhatsApp(sosMessage!),
                  icon: const Icon(Icons.chat_rounded, size: 14),
                  label: Text(
                    EmergencyAssistanceLocalization.shareWhatsApp(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _shareViaSms(sosMessage!),
                  icon: const Icon(Icons.sms_rounded, size: 14),
                  label: Text(
                    EmergencyAssistanceLocalization.shareSms(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => EmergencyCallService.copyToClipboard(
                    context,
                    mapUrl!,
                    _isTamil
                        ? '✓ இருப்பிட இணைப்பு நகலெடுக்கப்பட்டது'
                        : '✓ Location link copied to clipboard',
                  ),
                  icon: const Icon(Icons.link_rounded, size: 14),
                  label: Text(
                    EmergencyAssistanceLocalization.copyLink(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xff334155),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xffCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => EmergencyCallService.copyToClipboard(
                    context,
                    sosMessage!,
                    _isTamil
                        ? '✓ அவசர செய்தி நகலெடுக்கப்பட்டது'
                        : '✓ Emergency message copied to clipboard',
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(
                    EmergencyAssistanceLocalization.copyMessage(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xff334155),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xffCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff141B26) : const Color(0xffFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xffFFB020).withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_rounded,
                    size: 16,
                    color: Color(0xffFFB020),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      EmergencyAssistanceLocalization.gpsUnavailable(_isTamil),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xff78350F),
                      ),
                    ),
                  ),
                  if (widget.onRefreshLocation != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _refreshLocation,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        foregroundColor: const Color(0xff00E5A8),
                      ),
                      child: Text(
                        _isTamil ? 'கண்டறி' : 'Detect',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyServicesSection(bool isDark, bool isMobile) {
    final hospital = _findNearestHospital();
    final policeStation = _findNearestPoliceStation();

    final services = [
      _ServiceItem(
        title: EmergencyAssistanceLocalization.police(_isTamil),
        number: '112',
        desc: EmergencyAssistanceLocalization.policeDesc(_isTamil),
        icon: Icons.local_police_rounded,
        color: const Color(0xff3B82F6),
        isAvailable: true,
      ),
      if (policeStation != null)
        _ServiceItem(
          title: EmergencyAssistanceLocalization.nearbyPoliceStation(_isTamil),
          number: policeStation.phone ?? 'View',
          desc: policeStation.name ?? 'Nearby Police Station',
          icon: Icons.shield_rounded,
          color: const Color(0xff2563EB),
          isAvailable: true,
          hospitalObj: policeStation,
        ),
      _ServiceItem(
        title: EmergencyAssistanceLocalization.ambulance(_isTamil),
        number: '108',
        desc: EmergencyAssistanceLocalization.ambulanceDesc(_isTamil),
        icon: Icons.medical_services_rounded,
        color: const Color(0xff10B981),
        isAvailable: true,
      ),
      _ServiceItem(
        title: EmergencyAssistanceLocalization.fire(_isTamil),
        number: '101',
        desc: EmergencyAssistanceLocalization.fireDesc(_isTamil),
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xffF97316),
        isAvailable: true,
      ),
      _ServiceItem(
        title: EmergencyAssistanceLocalization.hospital(_isTamil),
        number: hospital?.phone ?? (hospital != null ? 'View' : null),
        desc: hospital != null
            ? (hospital.name ?? 'Nearby Medical Hospital')
            : EmergencyAssistanceLocalization.hospitalUnavailable(_isTamil),
        icon: Icons.local_hospital_rounded,
        color: const Color(0xffEC4899),
        isAvailable: hospital != null,
        hospitalObj: hospital,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in services) ...[
          _buildServiceCard(item, isDark),
          const SizedBox(height: 8),
        ],
        if (widget.onOpenNearbyPlaces != null) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: widget.onOpenNearbyPlaces,
            style: OutlinedButton.styleFrom(
              foregroundColor: NeonTheme.neonCyan,
              side: const BorderSide(color: NeonTheme.neonCyan, width: 1.1),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.location_on_rounded, size: 16),
            label: Text(
              _isTamil
                  ? 'அருகிலுள்ள பாதுகாப்பு வசதிகளை காண்க'
                  : 'Explore Nearby Safety Facilities',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceCard(_ServiceItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.8)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (item.number != null && item.number != 'View') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.number!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: item.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: item.isAvailable
                        ? (isDark
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight)
                        : (isDark ? Colors.white38 : const Color(0xff94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.number != null && item.number != 'View') ...[
            ElevatedButton.icon(
              onPressed: () {
                EmergencyCallService.initiateCallWithConfirmation(
                  context: context,
                  serviceName: item.title,
                  phoneNumber: item.number!,
                  isTamil: _isTamil,
                  isDarkMode: widget.isDarkMode,
                );
              },
              icon: const Icon(Icons.call_rounded, size: 13),
              label: Text(
                EmergencyAssistanceLocalization.call(_isTamil),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: item.color,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ] else if (item.hospitalObj != null && item.number == 'View') ...[
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: item.color,
                side: BorderSide(color: item.color, width: 1),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('View', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteContextSection(bool isDark) {
    final hasRoute =
        widget.routeOrigin != null && widget.routeDestination != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 15,
                color: NeonTheme.neonCyan,
              ),
              const SizedBox(width: 6),
              Text(
                hasRoute
                    ? EmergencyAssistanceLocalization.currentRouteHeading(
                        _isTamil,
                      )
                    : EmergencyAssistanceLocalization.noRouteHeading(_isTamil),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.neonCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasRoute) ...[
            Text(
              '${widget.routeOrigin} → ${widget.routeDestination}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.vehicleMode ?? 'Car'} · ${widget.travelTimeMode ?? 'Day'} · '
              '${widget.distanceKm != null ? '${widget.distanceKm!.toStringAsFixed(1)} km' : '--'} · '
              '${widget.durationMinutes != null ? widget.formatDurationFn(widget.durationMinutes!) : '--'}',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
            if (widget.safetyScore != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Safety Score: ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${widget.safetyScore!.round()} / 100',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: NeonTheme.safeGreen,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            Text(
              EmergencyAssistanceLocalization.noRoutePrompt(_isTamil),
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyFactorsContext(bool isDark) {
    final factors = widget.personalizedSafetyResult?.factors ?? [];
    if (factors.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: NeonTheme.warningGold,
              ),
              const SizedBox(width: 6),
              Text(
                EmergencyAssistanceLocalization.safetyContextHeading(_isTamil),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.warningGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final f in factors)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        f.icon,
                        size: 12,
                        color: f.score != null
                            ? NeonTheme.neonCyan
                            : (isDark
                                  ? NeonTheme.textSecondaryDark
                                  : Colors.grey),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${f.title}: ',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight,
                        ),
                      ),
                      Text(
                        f.score != null
                            ? '${f.score!.round()}%'
                            : 'Unavailable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: f.score != null
                              ? NeonTheme.safeGreen
                              : (isDark
                                    ? NeonTheme.textSecondaryDark
                                    : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contacts_rounded,
                size: 15,
                color: NeonTheme.neonAmber,
              ),
              const SizedBox(width: 6),
              Text(
                EmergencyAssistanceLocalization.emergencyContactsHeading(
                  _isTamil,
                ),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.neonAmber,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAddContactForm = !_showAddContactForm;
                  });
                },
                icon: Icon(
                  _showAddContactForm ? Icons.close : Icons.add_rounded,
                  size: 14,
                  color: NeonTheme.neonAmber,
                ),
                label: Text(
                  _showAddContactForm
                      ? EmergencyAssistanceLocalization.cancel(_isTamil)
                      : EmergencyAssistanceLocalization.addContact(_isTamil),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NeonTheme.neonAmber,
                  ),
                ),
              ),
            ],
          ),
          if (_showAddContactForm) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: EmergencyAssistanceLocalization.contactNameHint(
                        _isTamil,
                      ),
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? NeonTheme.cardElevatedDark
                          : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          EmergencyAssistanceLocalization.contactPhoneHint(
                            _isTamil,
                          ),
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? NeonTheme.cardElevatedDark
                          : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.neonAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    EmergencyAssistanceLocalization.save(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (!_contactsLoaded) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
          ] else if (_contacts.isEmpty && !_showAddContactForm) ...[
            Text(
              EmergencyAssistanceLocalization.noContactsSaved(_isTamil),
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ] else ...[
            for (final c in _contacts) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? NeonTheme.cardElevatedDark : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: NeonTheme.neonAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            c.phone,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? NeonTheme.textSecondaryDark
                                  : NeonTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_activePosition != null &&
                        EmergencyLocationHelper.isValidCoordinate(
                          _activePosition!.latitude,
                          _activePosition!.longitude,
                        ))
                      IconButton(
                        icon: const Icon(
                          Icons.share_location_rounded,
                          size: 16,
                          color: Color(0xff25D366),
                        ),
                        onPressed: () {
                          final msg = EmergencyLocationHelper.buildSosMessage(
                            latitude: _activePosition!.latitude,
                            longitude: _activePosition!.longitude,
                            accuracyMeters: _activePosition!.accuracy,
                            routeOrigin: widget.routeOrigin,
                            routeDestination: widget.routeDestination,
                          );
                          _shareViaWhatsApp(msg, phoneNumber: c.phone);
                        },
                        tooltip: _isTamil
                            ? 'SOS அனுப்பு (WhatsApp)'
                            : 'Send SOS via WhatsApp',
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.call_rounded,
                        size: 16,
                        color: NeonTheme.safeGreen,
                      ),
                      onPressed: () {
                        EmergencyCallService.initiateCallWithConfirmation(
                          context: context,
                          serviceName: c.name,
                          phoneNumber: c.phone,
                          isTamil: _isTamil,
                          isDarkMode: widget.isDarkMode,
                        );
                      },
                      tooltip: EmergencyAssistanceLocalization.call(_isTamil),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: NeonTheme.dangerRed,
                      ),
                      onPressed: () => _deleteContact(c),
                      tooltip: EmergencyAssistanceLocalization.delete(_isTamil),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 6),
          Text(
            EmergencyAssistanceLocalization.privacyNote(_isTamil),
            style: TextStyle(
              fontSize: 9.5,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyDisclaimer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 14, color: NeonTheme.neonCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              EmergencyAssistanceLocalization.callDisclaimer(_isTamil),
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: NeonTheme.dangerRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            EmergencyAssistanceLocalization.close(_isTamil).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceItem {
  final String title;
  final String? number;
  final String desc;
  final IconData icon;
  final Color color;
  final bool isAvailable;
  final Facility? hospitalObj;

  const _ServiceItem({
    required this.title,
    this.number,
    required this.desc,
    required this.icon,
    required this.color,
    required this.isAvailable,
    this.hospitalObj,
  });
}
