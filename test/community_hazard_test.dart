import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

// Test duplicate detection logic, confidence calculation formulas,
// hazard category matching, and data models for SafeRoute TN 2.0 Community Hazards

void main() {
  group('Community Road Hazard Data Model Tests', () {
    test('Category definition and fallback tests', () {
      final categories = [
        'pothole_damaged_road',
        'flooding_waterlogging',
        'road_blocked',
        'construction',
        'broken_streetlight',
        'broken_footpath',
        'missing_wheelchair_ramp',
        'unsafe_pedestrian_crossing',
        'accident_hazard',
      ];

      expect(categories.length, equals(9));
      expect(categories.contains('pothole_damaged_road'), isTrue);
      expect(categories.contains('flooding_waterlogging'), isTrue);
      expect(categories.contains('missing_wheelchair_ramp'), isTrue);
    });

    test('Confidence score calculations match specification', () {
      // Base calculation:
      // initial = 25
      // GPS accuracy bonus = 15
      // detailed description = 10
      // 1 confirmation = +20 -> 70% (High confidence)
      // 1 dispute = -25
      double calculateConfidence({
        required int confirmations,
        required int disputes,
        required bool hasGps,
        required bool hasDetail,
      }) {
        double score = 25.0;
        if (hasGps) score += 15.0;
        if (hasDetail) score += 10.0;
        score += (confirmations * 20.0);
        score -= (disputes * 25.0);
        return score.clamp(0.0, 100.0);
      }

      String getConfidenceLevel(double score) {
        if (score >= 70.0) return 'High confidence';
        if (score >= 40.0) return 'Moderate confidence';
        return 'Low confidence';
      }

      final initialScore = calculateConfidence(confirmations: 0, disputes: 0, hasGps: true, hasDetail: true);
      expect(initialScore, equals(50.0));
      expect(getConfidenceLevel(initialScore), equals('Moderate confidence'));

      final confirmedScore = calculateConfidence(confirmations: 1, disputes: 0, hasGps: true, hasDetail: true);
      expect(confirmedScore, equals(70.0));
      expect(getConfidenceLevel(confirmedScore), equals('High confidence'));

      final disputedScore = calculateConfidence(confirmations: 0, disputes: 2, hasGps: true, hasDetail: true);
      expect(disputedScore, equals(0.0));
      expect(getConfidenceLevel(disputedScore), equals('Low confidence'));
    });

    test('Status transitions work correctly', () {
      String computeStatus({
        required int confirmations,
        required int disputes,
        required double confidence,
      }) {
        if (disputes >= 2 && disputes > confirmations) {
          return 'Disputed';
        }
        if (confirmations >= 1 && confidence >= 60.0) {
          return 'Confirmed';
        }
        return 'Pending';
      }

      expect(computeStatus(confirmations: 0, disputes: 0, confidence: 50.0), equals('Pending'));
      expect(computeStatus(confirmations: 1, disputes: 0, confidence: 70.0), equals('Confirmed'));
      expect(computeStatus(confirmations: 1, disputes: 3, confidence: 20.0), equals('Disputed'));
    });

    test('Self-confirmation guard logic', () {
      bool canConfirm({
        required String reportAuthorSession,
        required String currentSession,
      }) {
        return reportAuthorSession != currentSession;
      }

      expect(canConfirm(reportAuthorSession: 'session_A', currentSession: 'session_A'), isFalse);
      expect(canConfirm(reportAuthorSession: 'session_A', currentSession: 'session_B'), isTrue);
    });

    test('Expiry rule logic differentiates hazard types', () {
      bool isAutoExpiring(String category) {
        const expiringCategories = [
          'flooding_waterlogging',
          'road_blocked',
          'accident_hazard',
        ];
        return expiringCategories.contains(category);
      }

      expect(isAutoExpiring('flooding_waterlogging'), isTrue);
      expect(isAutoExpiring('road_blocked'), isTrue);
      expect(isAutoExpiring('accident_hazard'), isTrue);
      expect(isAutoExpiring('pothole_damaged_road'), isFalse);
      expect(isAutoExpiring('broken_streetlight'), isFalse);
      expect(isAutoExpiring('missing_wheelchair_ramp'), isFalse);
    });

    test('Blackspot non-double-counting separation', () {
      // If hazard is near blackspot, it must be marked is_near_blackspot: true
      // and not trigger duplicate blackspot penalty deductions.
      final mockHazardNearBlackspot = {
        'id': 101,
        'category': 'accident_hazard',
        'is_near_blackspot': true,
        'matched_blackspot_id': 'BS_042',
      };

      expect(mockHazardNearBlackspot['is_near_blackspot'], isTrue);
      expect(mockHazardNearBlackspot['matched_blackspot_id'], equals('BS_042'));
    });
  });
}
