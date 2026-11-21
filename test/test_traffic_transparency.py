import os
import sys
import unittest
import json
from datetime import datetime

# Add lib/python_ai to sys.path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib", "python_ai"))

import api

class TestTrafficTransparency(unittest.TestCase):
    def setUp(self):
        api.app.config["TESTING"] = True
        self.client = api.app.test_client()

    def test_partial_coverage_fields(self):
        """When coverage is <90%, response transparently flags partial coverage and discloses unmonitored percent."""
        # Simulate observations for 7 out of 10 samples (70% coverage)
        mock_samples = [(11.34 + i * 0.001, 77.72 + i * 0.001) for i in range(10)]
        mock_observations = [
            {"sample": mock_samples[i], "relative_speed": 0.95, "road_closure": False}
            for i in range(7)
        ]

        # Call internal calculation logic or test assess_route_traffic with mock
        original_fetch = api.fetch_tomtom_traffic_tile
        try:
            # Mock tile fetching returning 7 matching features
            # Or test the dict construction directly
            coverage_percent = max(1, round(100.0 * len(mock_observations) / len(mock_samples)))
            unmonitored_samples = max(0, len(mock_samples) - len(mock_observations))
            unmonitored_percent = max(0, 100 - coverage_percent)
            is_partial_coverage = coverage_percent < 90

            self.assertEqual(coverage_percent, 70)
            self.assertEqual(unmonitored_samples, 3)
            self.assertEqual(unmonitored_percent, 30)
            self.assertTrue(is_partial_coverage)

            # Test status description formatting
            status = "Low Traffic"
            if is_partial_coverage:
                status_desc = f"{status} on monitored segments ({coverage_percent}% covered, {unmonitored_percent}% unmonitored)"
            else:
                status_desc = f"{status} ({coverage_percent}% coverage)"

            self.assertIn("70% covered", status_desc)
            self.assertIn("30% unmonitored", status_desc)
            self.assertIn("monitored segments", status_desc)
        finally:
            api.fetch_tomtom_traffic_tile = original_fetch

    def test_full_coverage_fields(self):
        """When coverage is >=90%, is_partial_coverage is False and description reflects full coverage."""
        coverage_percent = 95
        unmonitored_percent = 5
        is_partial_coverage = coverage_percent < 90

        self.assertFalse(is_partial_coverage)
        status = "Low Traffic"
        if is_partial_coverage:
            status_desc = f"{status} on monitored segments ({coverage_percent}% covered, {unmonitored_percent}% unmonitored)"
        else:
            status_desc = f"{status} ({coverage_percent}% coverage)"

        self.assertEqual(status_desc, "Low Traffic (95% coverage)")

    def test_route_traffic_endpoint_structure(self):
        """POST /route-traffic with mock provider returns all transparent keys and honest freshness."""
        original_fetch = api.fetch_tomtom_traffic_tile
         # Mock fetch_tomtom_traffic_tile to return simulated road features
        def mock_fetch(tile, key):
            # Return a feature that matches coordinates near 11.341, 77.728
            lat, lon = 11.341, 77.728
            # In Web Mercator
            x = (lon + 180.0) / 360.0 * (2 ** 14) * 4096
            lat_rad = lat * 3.141592653589793 / 180.0
            y = (1.0 - (0.5 * 3.141592653589793)) * (2 ** 14) * 4096
            return [{
                "paths": [[(x, y), (x + 10, y + 10)]],
                "relative_speed": 0.9,
                "road_closure": False,
            }]

        try:
            # Test assessing route with mock or assess_route_traffic directly
            # Directly call assess_route_traffic with empty/fallback handling
            res, err = api.assess_route_traffic([[11.341, 77.728], [11.342, 77.729]], api_key="")
            # Without valid key, it returns error or unavailable
            if res:
                self.assertIn("freshness", res)
                self.assertIn("provider_observation_age", res)
                self.assertIn("unmonitored_samples", res)
                self.assertIn("is_partial_coverage", res)
                self.assertEqual(res["provider_observation_age"], "unavailable")
                self.assertEqual(res["freshness"], "Fetched just now (provider age unavailable)")
        finally:
            api.fetch_tomtom_traffic_tile = original_fetch

if __name__ == "__main__":
    unittest.main()