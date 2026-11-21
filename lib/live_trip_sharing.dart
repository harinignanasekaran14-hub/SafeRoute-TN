import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'emergency_assistance.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class LiveSharedTripSession {
  final String shareToken;
  final String updateToken;
  final String destination;
  final String? origin;
  final String vehicle;
  final int? etaMinutes;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;

  const LiveSharedTripSession({
    required this.shareToken,
    required this.updateToken,
    required this.destination,
    this.origin,
    this.vehicle = 'Car',
    this.etaMinutes,
    required this.createdAt,
    required this.expiresAt,
    this.status = 'active',
  });

  factory LiveSharedTripSession.fromJson(Map<String, dynamic> json) {
    return LiveSharedTripSession(
      shareToken: json['share_token'] as String? ?? '',
      updateToken: json['update_token'] as String? ?? '',
      destination: json['destination'] as String? ?? 'Destination',
      origin: json['origin'] as String?,
      vehicle: json['vehicle'] as String? ?? 'Car',
      etaMinutes: json['eta_minutes'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String) ??
              DateTime.now().add(const Duration(hours: 12))
          : DateTime.now().add(const Duration(hours: 12)),
      status: json['status'] as String? ?? 'active',
    );
  }
}

class LiveSharedTripStatus {
  final String status; // active, paused, completed, stopped, expired, not_found, error
  final String destination;
  final String? origin;
  final String? vehicle;
  final int? etaMinutes;
  final double? latitude;
  final double? longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime? updatedAt;
  final bool isStale;
  final int staleSeconds;
  final String? message;
  final DateTime? completedAt;

  const LiveSharedTripStatus({
    required this.status,
    required this.destination,
    this.origin,
    this.vehicle,
    this.etaMinutes,
    this.latitude,
    this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    this.updatedAt,
    this.isStale = false,
    this.staleSeconds = 0,
    this.message,
    this.completedAt,
  });

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90.0 &&
      latitude! <= 90.0 &&
      longitude! >= -180.0 &&
      longitude! <= 180.0;

  factory LiveSharedTripStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'unknown';
    final destination = json['destination'] as String? ?? 'Destination';
    final origin = json['origin'] as String?;
    final vehicle = json['vehicle'] as String?;
    final etaMinutes = json['eta_minutes'] as int?;

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final lat = parseDouble(json['latitude']);
    final lon = parseDouble(json['longitude']);
    final heading = parseDouble(json['heading']);
    final speed = parseDouble(json['speed']);
    final accuracy = parseDouble(json['accuracy']);
    final isStale = json['is_stale'] as bool? ?? false;
    final staleSeconds = (json['stale_seconds'] as num?)?.toInt() ?? 0;
    final message = json['message'] as String?;

    final updatedAt = json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null;
    final completedAt = json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'] as String)
        : null;

    return LiveSharedTripStatus(
      status: status,
      destination: destination,
      origin: origin,
      vehicle: vehicle,
      etaMinutes: etaMinutes,
      latitude: lat,
      longitude: lon,
      heading: heading,
      speed: speed,
      accuracy: accuracy,
      updatedAt: updatedAt,
      isStale: isStale,
      staleSeconds: staleSeconds,
      message: message,
      completedAt: completedAt,
    );
  }
}

// ============================================================================
// SERVICE: LIVE TRIP SHARING CLIENT
// ============================================================================

class LiveTripSharingService {
  static String get baseUrl {
    final uriBase = Uri.base;
    if (uriBase.hasScheme && uriBase.host.isNotEmpty) {
      if (uriBase.host == 'localhost' || uriBase.host == '127.0.0.1') {
        return '${uriBase.scheme}://${uriBase.host}:5000';
      }
    }
    return 'http://127.0.0.1:5000';
  }

  static String buildShareUrl(String shareToken) {
    final uriBase = Uri.base;
    if (uriBase.hasScheme && uriBase.host.isNotEmpty) {
      final portPart = (uriBase.hasPort && uriBase.port != 80 && uriBase.port != 443)
          ? ':${uriBase.port}'
          : '';
      return '${uriBase.scheme}://${uriBase.host}$portPart/?share_token=$shareToken';
    }
    return 'https://saferoute.tn/?share_token=$shareToken';
  }

  static String buildShareMessage({
    required String destination,
    required String shareUrl,
    int? etaMinutes,
    String vehicle = 'Car',
    bool isTamil = false,
  }) {
    final etaStr = etaMinutes != null && etaMinutes > 0
        ? (isTamil ? ' • எதிர்பார்க்கும் நேரம்: ~$etaMinutes நிமிடம்' : ' • ETA: ~$etaMinutes min')
        : '';

    if (isTamil) {
      return '''SafeRoute TN – நேரலை பயணப் பகிர்வு
நான் $destination நோக்கி பயணிக்கிறேன் ($vehicle$etaStr).
எனது நேரலை பயணம் மற்றும் வருகை நேரத்தை இங்கே கண்காணிக்கவும்:
$shareUrl

(வழிசெலுத்தல் செயலில் இருக்கும் வரை நேரலை பகிர்வு செயல்படும் · 12 மணி நேரத்தில் தானாக காலாவதியாகும்)''';
    }

    return '''SafeRoute TN – Live Trip Tracking
I am heading to $destination ($vehicle$etaStr).
Track my live location and arrival time here:
$shareUrl

(Sharing is live while navigation is active · Automatically expires in 12h)''';
  }

  static String buildSafeArrivalMessage({
    required String destination,
    bool isTamil = false,
  }) {
    if (isTamil) {
      return '''SafeRoute TN – பாதுகாப்பான வருகை
நான் $destination-ஐ பத்திரமாக அடைந்துவிட்டேன்! நேரலை பகிர்வு நிறைவடைந்தது. நன்றி.''';
    }

    return '''SafeRoute TN – Safe Arrival
I have arrived safely at $destination! Live trip sharing is now completed. Thank you.''';
  }

  static Future<LiveSharedTripSession?> createShareSession({
    required String destination,
    String? origin,
    String vehicle = 'Car',
    int? etaMinutes,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$baseUrl/api/trip/create_share');
      final Map<String, dynamic> body = {
        'destination': destination,
        'vehicle': vehicle,
      };
      if (origin != null && origin.trim().isNotEmpty) {
        body['origin'] = origin.trim();
      }
      if (etaMinutes != null) body['eta_minutes'] = etaMinutes;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (heading != null) body['heading'] = heading;
      if (speed != null) body['speed'] = speed;
      if (accuracy != null) body['accuracy'] = accuracy;

      final response = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return LiveSharedTripSession.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating live trip share session: $e');
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<bool> updateLocation({
    required String updateToken,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    int? etaMinutes,
    String status = 'active',
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$baseUrl/api/trip/update_location');
      final Map<String, dynamic> body = {
        'update_token': updateToken,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
      };
      if (heading != null) body['heading'] = heading;
      if (speed != null) body['speed'] = speed;
      if (accuracy != null) body['accuracy'] = accuracy;
      if (etaMinutes != null) body['eta_minutes'] = etaMinutes;

      final response = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating trip location: $e');
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<LiveSharedTripStatus?> fetchTripStatus(
    String shareToken, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$baseUrl/api/trip/status/${Uri.encodeComponent(shareToken.trim())}');
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return LiveSharedTripStatus.fromJson(data);
        }
      } else if (response.statusCode == 404) {
        return const LiveSharedTripStatus(
          status: 'not_found',
          destination: 'Trip Not Found',
          message: 'This trip sharing link does not exist or was deleted.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching shared trip status: $e');
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<bool> stopSharing(
    String updateToken, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$baseUrl/api/trip/stop_sharing');
      final response = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'update_token': updateToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error stopping trip sharing: $e');
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<bool> completeTrip(
    String updateToken, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse('$baseUrl/api/trip/complete_trip');
      final response = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'update_token': updateToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error completing trip sharing: $e');
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<bool> shareViaWhatsApp(
    BuildContext context,
    String message, {
    String? phoneNumber,
  }) async {
    final uri = EmergencyLocationHelper.buildWhatsAppUri(message, phoneNumber: phoneNumber);
    final launched = await EmergencyCallService.launchExternalUri(
      context,
      uri,
      failureFallback: 'Unable to launch WhatsApp. Message copied to clipboard instead.',
    );
    if (!launched && context.mounted) {
      await copyToClipboard(context, message, successMessage: 'Message copied to clipboard.');
    }
    return launched;
  }

  static Future<bool> shareViaSms(
    BuildContext context,
    String message, {
    String? phoneNumber,
  }) async {
    final uri = EmergencyLocationHelper.buildSmsUri(message, phoneNumber: phoneNumber);
    final launched = await EmergencyCallService.launchExternalUri(
      context,
      uri,
      failureFallback: 'Unable to launch SMS. Message copied to clipboard instead.',
    );
    if (!launched && context.mounted) {
      await copyToClipboard(context, message, successMessage: 'Message copied to clipboard.');
    }
    return launched;
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String? successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage ?? 'Copied to clipboard!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xff0B1D3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ============================================================================
// DIALOG 1: OPT-IN CONSENT DIALOG BEFORE SHARING
// ============================================================================

class LiveTripSharingConsentDialog extends StatefulWidget {
  final String destination;
  final String? origin;
  final String vehicle;
  final int? etaMinutes;
  final double? latitude;
  final double? longitude;
  final bool isDarkMode;
  final bool isTamil;

  const LiveTripSharingConsentDialog({
    super.key,
    required this.destination,
    this.origin,
    this.vehicle = 'Car',
    this.etaMinutes,
    this.latitude,
    this.longitude,
    this.isDarkMode = true,
    this.isTamil = false,
  });

  @override
  State<LiveTripSharingConsentDialog> createState() =>
      _LiveTripSharingConsentDialogState();
}

class _LiveTripSharingConsentDialogState
    extends State<LiveTripSharingConsentDialog> {
  List<EmergencyContact> _contacts = [];
  bool _loadingContacts = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await EmergencyContactsStorage.loadContacts();
      if (mounted) {
        setState(() {
          _contacts = list;
          _loadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final isTamil = widget.isTamil;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xf5061224) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff00E5FF), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff00E5FF).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0B1D3A) : const Color(0xffF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xff1E345B) : const Color(0xffCBD5E1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xff00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff00E5FF), width: 1.2),
                      ),
                      child: const Icon(
                        Icons.share_location_rounded,
                        color: Color(0xff00E5FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTamil ? 'நேரலை பயணப் பகிர்வு' : 'Share Live Trip',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xff0F172A),
                            ),
                          ),
                          Text(
                            isTamil
                                ? 'நம்பகமான நபர்களுக்கு உங்கள் பயணத்தை நேரலையாக பகிரவும்'
                                : 'Let family & friends track your journey and arrival',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : const Color(0xff64748B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Destination preview pill
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff0E2243) : const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xff1E3E6D) : const Color(0xffE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xff00E5FF), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTamil ? 'இலக்கு' : 'Destination',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xff00E5FF) : const Color(0xff0284C7),
                                  ),
                                ),
                                Text(
                                  widget.destination,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xff0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (widget.etaMinutes != null && widget.etaMinutes! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xff10B981).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xff10B981), width: 0.8),
                              ),
                              child: Text(
                                '~${widget.etaMinutes} min',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Privacy Highlights
                    _buildDisclosureItem(
                      icon: Icons.lock_outline_rounded,
                      title: isTamil ? 'பாதுகாப்பான டோக்கன் இணைப்பு' : 'Secure Token-Based Link',
                      subtitle: isTamil
                          ? 'தனித்துவமான, கணிக்க முடியாத இணைப்பு வழியாக மட்டுமே பார்க்க முடியும்.'
                          : 'Only people with this unique link can view your live progress.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildDisclosureItem(
                      icon: Icons.timer_outlined,
                      title: isTamil ? '12 மணி நேரத்தில் காலாவதியாகும்' : 'Auto-Expires in 12 Hours',
                      subtitle: isTamil
                          ? 'பயணம் முடிந்தவுடன் அல்லது 12 மணி நேரத்திற்குப் பிறகு இணைப்பு காலாவதியாகும்.'
                          : 'Session automatically expires after trip completion or 12 hours.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildDisclosureItem(
                      icon: Icons.tab_unselected_rounded,
                      title: isTamil ? 'செயலில் உள்ள உலாவி தாவல் தேவை' : 'Requires Active Browser Tab',
                      subtitle: isTamil
                          ? 'உலாவி தாவல் மூடப்பட்டாலோ அல்லது இடைநிறுத்தப்பட்டாலோ நேரலை புதுப்பிப்புகள் நிற்கும்.'
                          : 'Updates only stream while this navigation tab is open and active.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    // Quick contacts list if available
                    if (!_loadingContacts && _contacts.isNotEmpty) ...[
                      Text(
                        isTamil ? 'உடனடி தொடர்புகள்:' : 'Saved Contacts:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xff475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in _contacts.take(3))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xff102544) : const Color(0xffF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xff1E3E6D) : const Color(0xffCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_rounded, size: 12, color: Color(0xff00E5FF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xff0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              isTamil ? 'ரத்து' : 'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xff475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00B4D8),
                              foregroundColor: const Color(0xff051329),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xff051329)),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded, size: 18),
                            label: Text(
                              isTamil ? 'நேரலை பகிர்வை துவங்கு' : 'Enable Live Sharing',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            onPressed: _isCreating
                                ? null
                                : () async {
                                    setState(() => _isCreating = true);
                                    final session = await LiveTripSharingService.createShareSession(
                                      destination: widget.destination,
                                      origin: widget.origin,
                                      vehicle: widget.vehicle,
                                      etaMinutes: widget.etaMinutes,
                                      latitude: widget.latitude,
                                      longitude: widget.longitude,
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop(session);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclosureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xff00E5FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xff0F172A),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white60 : const Color(0xff64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOG 2: ACTIVE TRIP SHARING CONTROLS
// ============================================================================

class LiveTripSharingActiveDialog extends StatefulWidget {
  final LiveSharedTripSession session;
  final bool isDarkMode;
  final bool isTamil;
  final VoidCallback onStopSharing;

  const LiveTripSharingActiveDialog({
    super.key,
    required this.session,
    required this.onStopSharing,
    this.isDarkMode = true,
    this.isTamil = false,
  });

  @override
  State<LiveTripSharingActiveDialog> createState() =>
      _LiveTripSharingActiveDialogState();
}

class _LiveTripSharingActiveDialogState
    extends State<LiveTripSharingActiveDialog> {
  List<EmergencyContact> _contacts = [];
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await EmergencyContactsStorage.loadContacts();
      if (mounted) setState(() => _contacts = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final isTamil = widget.isTamil;
    final shareUrl = LiveTripSharingService.buildShareUrl(widget.session.shareToken);
    final shareMsg = LiveTripSharingService.buildShareMessage(
      destination: widget.session.destination,
      shareUrl: shareUrl,
      etaMinutes: widget.session.etaMinutes,
      vehicle: widget.session.vehicle,
      isTamil: isTamil,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xf5061224) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff10B981), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff10B981).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff082F24) : const Color(0xffECFDF5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xff065F46) : const Color(0xffA7F3D0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xff10B981).withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff10B981), width: 1.2),
                      ),
                      child: const Icon(
                        Icons.sensors_rounded,
                        color: Color(0xff10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTamil ? 'நேரலை பகிர்வு செயலில் உள்ளது' : 'Live Sharing Active',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff10B981),
                            ),
                          ),
                          Text(
                            isTamil
                                ? 'உங்கள் GPS இருப்பிடம் நம்பகமான தொடர்புகளுடன் பகிரப்படுகிறது'
                                : 'Streaming genuine GPS fixes to your shared link',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xff047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : const Color(0xff64748B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Link box with Copy Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff0B1D3A) : const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xff1E345B) : const Color(0xffCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              shareUrl,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xff00E5FF) : const Color(0xff0284C7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF).withValues(alpha: 0.18),
                              foregroundColor: const Color(0xff00E5FF),
                              side: const BorderSide(color: Color(0xff00E5FF), width: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: Text(
                              isTamil ? 'நகலெடு' : 'Copy',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => LiveTripSharingService.copyToClipboard(
                              context,
                              shareUrl,
                              successMessage: isTamil
                                  ? 'நேரலை இணைப்பு நகலெடுக்கப்பட்டது!'
                                  : 'Live trip link copied to clipboard!',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quick Action Sharing Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 16),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            onPressed: () => LiveTripSharingService.shareViaWhatsApp(context, shareMsg),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.sms_rounded, size: 16),
                            label: const Text(
                              'SMS',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            onPressed: () => LiveTripSharingService.shareViaSms(context, shareMsg),
                          ),
                        ),
                      ],
                    ),
                    // Contact quick share list if contacts exist
                    if (_contacts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        isTamil ? 'சேமிக்கப்பட்ட தொடர்புகளுக்கு அனுப்பு:' : 'Send to Saved Contacts:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xff475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final contact in _contacts.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff0E2243) : const Color(0xffF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xff1E3E6D) : const Color(0xffE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 16, color: Color(0xff00E5FF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xff0F172A),
                                        ),
                                      ),
                                      Text(
                                        contact.phone,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.white60 : const Color(0xff64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat_rounded, size: 16, color: Color(0xff25D366)),
                                  tooltip: 'WhatsApp',
                                  onPressed: () => LiveTripSharingService.shareViaWhatsApp(
                                    context,
                                    shareMsg,
                                    phoneNumber: contact.phone,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.sms_rounded, size: 16, color: Color(0xff0284C7)),
                                  tooltip: 'SMS',
                                  onPressed: () => LiveTripSharingService.shareViaSms(
                                    context,
                                    shareMsg,
                                    phoneNumber: contact.phone,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    // Stop Sharing Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xffEF4444), width: 1.2),
                        foregroundColor: const Color(0xffEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: _isStopping
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xffEF4444)),
                              ),
                            )
                          : const Icon(Icons.stop_circle_rounded, size: 18),
                      label: Text(
                        isTamil ? 'பயணப் பகிர்வை உடனடியாக நிறுத்து' : 'Stop Sharing Trip Now',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      onPressed: _isStopping
                          ? null
                          : () async {
                              setState(() => _isStopping = true);
                              await LiveTripSharingService.stopSharing(widget.session.updateToken);
                              widget.onStopSharing();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG 3: SAFE ARRIVAL CONFIRMATION & NOTIFICATION
// ============================================================================

class SafeArrivalDialog extends StatefulWidget {
  final String destination;
  final bool isDarkMode;
  final bool isTamil;

  const SafeArrivalDialog({
    super.key,
    required this.destination,
    this.isDarkMode = true,
    this.isTamil = false,
  });

  @override
  State<SafeArrivalDialog> createState() => _SafeArrivalDialogState();
}

class _SafeArrivalDialogState extends State<SafeArrivalDialog> {
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final list = await EmergencyContactsStorage.loadContacts();
      if (mounted) setState(() => _contacts = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final isTamil = widget.isTamil;
    final arrivalMsg = LiveTripSharingService.buildSafeArrivalMessage(
      destination: widget.destination,
      isTamil: isTamil,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xf5061224) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff10B981), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff10B981).withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff065F46), Color(0xff064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff10B981), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xff34D399),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isTamil ? 'பாதுகாப்பான வருகை உறுதிசெய்யப்பட்டது!' : 'Safe Arrival Confirmed!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTamil
                          ? '${widget.destination}-ஐ பத்திரமாக அடைந்துவிட்டீர்கள். நேரலை பகிர்வு நிறைவடைந்தது.'
                          : 'You have safely reached ${widget.destination}. Live trip sharing completed.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xffA7F3D0),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTamil
                          ? 'வருகை செய்தியை தொடர்புகளுடன் பகிரவும்:'
                          : 'Notify contacts of your safe arrival:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xff0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 16),
                            label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => LiveTripSharingService.shareViaWhatsApp(context, arrivalMsg),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.sms_rounded, size: 16),
                            label: const Text('SMS', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => LiveTripSharingService.shareViaSms(context, arrivalMsg),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1)),
                        foregroundColor: isDark ? Colors.white70 : const Color(0xff475569),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        isTamil ? 'செய்தியை நகலெடு' : 'Copy Arrival Message',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                      onPressed: () => LiveTripSharingService.copyToClipboard(
                        context,
                        arrivalMsg,
                        successMessage: isTamil ? 'வருகை செய்தி நகலெடுக்கப்பட்டது!' : 'Arrival message copied!',
                      ),
                    ),
                    if (_contacts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final contact in _contacts.take(2))
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff0E2243) : const Color(0xffF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xff1E3E6D) : const Color(0xffE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 14, color: Color(0xff10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  contact.name,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xff0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.chat_rounded, size: 14, color: Color(0xff25D366)),
                                onPressed: () => LiveTripSharingService.shareViaWhatsApp(
                                  context,
                                  arrivalMsg,
                                  phoneNumber: contact.phone,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isTamil ? 'முடிந்தது' : 'Done',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET 4: PUBLIC READ-ONLY SHARED TRIP VIEWER
// ============================================================================

class SharedTripViewerDialog extends StatefulWidget {
  final String shareToken;
  final bool isDarkMode;

  const SharedTripViewerDialog({
    super.key,
    required this.shareToken,
    this.isDarkMode = true,
  });

  @override
  State<SharedTripViewerDialog> createState() => _SharedTripViewerDialogState();
}

/// Midnight Blue 4x5 ColorFilter matrix transforming OpenStreetMap raster tiles
/// into the premium SafeRoute TN Midnight Blue cartographic theme:
/// - Land background: Deep Navy (#101B2D)
/// - Secondary / Urban areas: Dark Blue-Grey (#17263B)
/// - Water areas: Dark Teal / Deep Blue (#0B263F)
/// - Roads: Muted Blue-Grey (#52657D)
/// - Labels / Boundaries: Soft Light Grey (#C5D0DF)
const List<double> _kMidnightBlueMapMatrix = <double>[
  0.01665, -0.46137, -0.52007, 0.0, 243.0,
 -0.00220, -0.49755, -0.43725, 0.0, 248.3,
  0.05488, -0.62461, -0.33520, 0.0, 259.3,
  0.0,      0.0,      0.0,     1.0,   0.0,
];

Widget _midnightBlueTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(_kMidnightBlueMapMatrix),
    child: tileWidget,
  );
}

class _SharedTripViewerDialogState extends State<SharedTripViewerDialog> {
  LiveSharedTripStatus? _status;
  bool _loading = true;
  Timer? _refreshTimer;
  final MapController _mapController = MapController();
  bool _isTamil = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchStatus(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final res = await LiveTripSharingService.fetchTripStatus(widget.shareToken);
    if (!mounted) return;
    setState(() {
      _status = res;
      _loading = false;
    });

    if (res != null && res.hasValidCoordinates) {
      try {
        _mapController.move(LatLng(res.latitude!, res.longitude!), 15.0);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xf5061224) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff00E5FF), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff00E5FF).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0B1D3A) : const Color(0xffF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xff1E345B) : const Color(0xffCBD5E1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xff00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff00E5FF), width: 1),
                      ),
                      child: const Icon(Icons.share_location_rounded, color: Color(0xff00E5FF), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isTamil ? 'SafeRoute TN · நேரலை கண்காணிப்பு' : 'SafeRoute TN · Live Trip Viewer',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xff0F172A),
                            ),
                          ),
                          Text(
                            _isTamil ? 'பொது பார்வை மட்டும் · 12 மணி நேரத்தில் காலாவதியாகும்' : 'Public read-only tracking · Auto-expires in 12h',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white60 : const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Language toggle
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => setState(() => _isTamil = !_isTamil),
                      child: Text(
                        _isTamil ? 'English' : 'தமிழ்',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff00E5FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : const Color(0xff64748B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00E5FF)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isTamil ? 'நேரலை நிலவரம் ஏற்றப்படுகிறது...' : 'Loading live trip status...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xff475569),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildTripContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripContent(bool isDark) {
    if (_status == null || _status!.status == 'not_found') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Color(0xffEF4444)),
              const SizedBox(height: 12),
              Text(
                _isTamil ? 'பயணம் காணப்படவில்லை' : 'Trip Not Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xff0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isTamil
                    ? 'இந்த நேரலை பகிர்வு இணைப்பு செல்லுபடியாகாது அல்லது நீக்கப்பட்டுள்ளது.'
                    : 'This live tracking link does not exist or has expired.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xff64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final s = _status!;
    final bool hasCoords = s.hasValidCoordinates;
    final LatLng centerPoint = hasCoords
        ? LatLng(s.latitude!, s.longitude!)
        : const LatLng(13.0827, 80.2707);

    return Column(
      children: [
        // Status & Destination strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xff0E2243) : const Color(0xffF8FAFC),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTamil ? 'இலக்கு:' : 'Heading toward:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xff00E5FF) : const Color(0xff0284C7),
                      ),
                    ),
                    Text(
                      s.destination,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xff0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusBadge(s),
            ],
          ),
        ),
        // Stale warning banner if stale
        if (s.status == 'active' && s.isStale)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xff7C2D12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xffFDBA74)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isTamil
                        ? 'இருப்பிடத் தகவல் காலாவதியானது (கடைசி GPS fix: ${s.staleSeconds ~/ 60} நிமிடம் முன்)'
                        : 'Location stale (Last fix ${s.staleSeconds ~/ 60} min ago · Waiting for live GPS)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffFDBA74),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Map Section
        Expanded(
          child: hasCoords
              ? FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centerPoint,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'org.saferoute.saferoute_tn',
                      tileBuilder: isDark ? _midnightBlueTileBuilder : null,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: centerPoint,
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xff00E5FF).withValues(alpha: 0.25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff00E5FF).withValues(alpha: 0.50),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Transform.rotate(
                                angle: ((s.heading ?? 0.0) * math.pi / 180.0),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xff00E5FF), Color(0xff0072FF)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.directions_car_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s.status == 'completed'
                              ? Icons.verified_rounded
                              : (s.status == 'stopped' ? Icons.stop_circle_rounded : Icons.location_off_rounded),
                          size: 44,
                          color: s.status == 'completed'
                              ? const Color(0xff10B981)
                              : (s.status == 'stopped' ? const Color(0xffEF4444) : const Color(0xffF59E0B)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.message ??
                              (s.status == 'completed'
                                  ? 'Arrived safely at destination!'
                                  : (s.status == 'stopped' ? 'Sharing has ended.' : 'Location currently unavailable.')),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xff0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // Bottom details bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff0B1D3A) : const Color(0xffF1F5F9),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (s.etaMinutes != null && s.etaMinutes! > 0 && s.status == 'active')
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xff00E5FF)),
                    const SizedBox(width: 4),
                    Text(
                      _isTamil ? 'வருகை நேரம்: ~${s.etaMinutes} நிமி' : 'ETA: ~${s.etaMinutes} min',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xff0F172A),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  s.status == 'completed'
                      ? (_isTamil ? 'பயணம் நிறைவுற்றது' : 'Trip Completed')
                      : (s.status == 'stopped' ? (_isTamil ? 'பகிர்வு நிறுத்தப்பட்டது' : 'Sharing Stopped') : 'SafeRoute TN'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xff475569),
                  ),
                ),
              if (s.updatedAt != null)
                Text(
                  _formatLastUpdated(s.updatedAt!),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : const Color(0xff64748B),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 15) return _isTamil ? 'இப்போதுதான்' : 'Just now';
    if (diff.inSeconds < 60) return _isTamil ? '${diff.inSeconds} வினாடிகள் முன்' : '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return _isTamil ? '${diff.inMinutes} நிமிடம் முன்' : '${diff.inMinutes}m ago';
    return dt.toLocal().toString().substring(11, 16);
  }

  Widget _buildStatusBadge(LiveSharedTripStatus s) {
    Color bg;
    Color fg;
    String label;

    switch (s.status) {
      case 'active':
        if (s.isStale) {
          bg = const Color(0xffF97316).withValues(alpha: 0.20);
          fg = const Color(0xffF97316);
          label = _isTamil ? 'பழைய தரவு' : 'STALE GPS';
        } else {
          bg = const Color(0xff10B981).withValues(alpha: 0.20);
          fg = const Color(0xff10B981);
          label = _isTamil ? 'நேரலை' : 'LIVE';
        }
        break;
      case 'paused':
        bg = const Color(0xffF59E0B).withValues(alpha: 0.20);
        fg = const Color(0xffF59E0B);
        label = _isTamil ? 'இடைநிறுத்தம்' : 'PAUSED';
        break;
      case 'completed':
        bg = const Color(0xff00E5FF).withValues(alpha: 0.20);
        fg = const Color(0xff00E5FF);
        label = _isTamil ? 'வந்தடைந்தார்' : 'ARRIVED';
        break;
      case 'stopped':
        bg = const Color(0xffEF4444).withValues(alpha: 0.20);
        fg = const Color(0xffEF4444);
        label = _isTamil ? 'நிறுத்தப்பட்டது' : 'STOPPED';
        break;
      case 'expired':
        bg = const Color(0xff64748B).withValues(alpha: 0.20);
        fg = const Color(0xff94A3B8);
        label = _isTamil ? 'காலாவதியானது' : 'EXPIRED';
        break;
      default:
        bg = const Color(0xff64748B).withValues(alpha: 0.20);
        fg = const Color(0xff94A3B8);
        label = s.status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
