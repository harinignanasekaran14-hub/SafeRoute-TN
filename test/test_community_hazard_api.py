import os
import sys
import unittest
import json

# Ensure project root is in path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib", "python_ai"))

from api import app, init_feedback_db, FEEDBACK_DB_PATH

class CommunityHazardApiTest(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()
        init_feedback_db()

    def test_01_valid_report_submission(self):
        payload = {
            "category": "pothole_damaged_road",
            "problem_type": "Pothole / damaged road",
            "severity": "High",
            "description": "Huge pothole on left lane near bypass toll gate",
            "location_landmark": "Toll gate km 24",
            "latitude": 11.3415,
            "longitude": 77.7285,
            "location_accuracy": 12.0,
            "user_session_id": "test_user_session_1",
            "force_new": True,
        }
        res = self.client.post("/road-report", json=payload)
        self.assertEqual(res.status_code, 201)
        data = json.loads(res.data)
        self.assertTrue(data.get("success"))
        self.assertEqual(data.get("status"), "Pending")
        self.assertIn("confidence_score", data)
        self.assertIn("report_id", data)

    def test_02_invalid_coordinates(self):
        payload = {
            "category": "flooding_waterlogging",
            "description": "Heavy water accumulation",
            "latitude": 150.0,  # Invalid latitude
            "longitude": 77.0,
            "user_session_id": "test_user_session_2",
        }
        res = self.client.post("/road-report", json=payload)
        self.assertEqual(res.status_code, 400)
        data = json.loads(res.data)
        self.assertFalse(data.get("success"))

    def test_03_missing_category(self):
        payload = {
            "description": "Road problem without category",
            "latitude": 11.0,
            "longitude": 77.0,
            "user_session_id": "test_user_session_3",
        }
        res = self.client.post("/road-report", json=payload)
        self.assertEqual(res.status_code, 400)
        data = json.loads(res.data)
        self.assertFalse(data.get("success"))

    def test_04_duplicate_report_detection(self):
        # First submission
        p1 = {
            "category": "road_blocked",
            "description": "Tree fallen across road",
            "latitude": 11.2000,
            "longitude": 77.5000,
            "user_session_id": "user_tree_1",
            "force_new": True,
        }
        r1 = self.client.post("/road-report", json=p1)
        self.assertEqual(r1.status_code, 201)

        # Duplicate within 20 meters without force_new
        p2 = {
            "category": "road_blocked",
            "description": "Large tree blocking both lanes",
            "latitude": 11.2001,
            "longitude": 77.5001,
            "user_session_id": "user_tree_2",
            "force_new": False,
        }
        r2 = self.client.post("/road-report", json=p2)
        self.assertEqual(r2.status_code, 409)
        data2 = json.loads(r2.data)
        self.assertTrue(data2.get("duplicate_detected"))

    def test_05_independent_confirmation_and_duplicate_prevention(self):
        # Create report
        p = {
            "category": "broken_streetlight",
            "description": "Streetlight cluster completely dark at junction",
            "latitude": 11.6500,
            "longitude": 78.1600,
            "user_session_id": "light_author_1",
            "force_new": True,
        }
        r = self.client.post("/road-report", json=p)
        rep_id = json.loads(r.data)["report_id"]

        # Self confirmation attempt should be forbidden (403)
        v_self = self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "light_author_1",
            "action": "still_there",
        })
        self.assertEqual(v_self.status_code, 403)

        # Independent confirmation 1
        v1 = self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "independent_user_1",
            "action": "still_there",
        })
        self.assertEqual(v1.status_code, 200)
        self.assertEqual(json.loads(v1.data)["confirmations_count"], 1)

        # Duplicate confirmation by same user should be 409
        v1_dup = self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "independent_user_1",
            "action": "still_there",
        })
        self.assertEqual(v1_dup.status_code, 409)

        # Independent confirmation 2 -> Transitions to Confirmed
        v2 = self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "independent_user_2",
            "action": "still_there",
        })
        self.assertEqual(v2.status_code, 200)
        data_v2 = json.loads(v2.data)
        self.assertEqual(data_v2["status"], "Confirmed")

    def test_06_dispute_and_resolve(self):
        p = {
            "category": "construction",
            "description": "Fake construction reported",
            "latitude": 12.5000,
            "longitude": 79.5000,
            "user_session_id": "prankster",
            "force_new": True,
        }
        r = self.client.post("/road-report", json=p)
        rep_id = json.loads(r.data)["report_id"]

        # Dispute 1
        self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "verifier_1",
            "action": "incorrect_report",
        })
        # Dispute 2
        d2 = self.client.post(f"/road-report/{rep_id}/verify", json={
            "user_session_id": "verifier_2",
            "action": "incorrect_location",
        })
        self.assertEqual(d2.status_code, 200)
        self.assertEqual(json.loads(d2.data)["status"], "Disputed")

    def test_07_route_query_and_my_reports(self):
        # Query reports along route
        pts = json.dumps([[11.3415, 77.7285], [11.6500, 78.1600]])
        res = self.client.get(f"/road-reports?points={pts}&radius_meters=1500")
        self.assertEqual(res.status_code, 200)
        data = json.loads(res.data)
        self.assertTrue(data["success"])
        self.assertGreaterEqual(len(data["reports"]), 1)

        # Query my reports
        my_res = self.client.get("/road-reports/my-reports?session_id=test_user_session_1")
        self.assertEqual(my_res.status_code, 200)
        my_data = json.loads(my_res.data)
        self.assertTrue(my_data["success"])
        self.assertGreaterEqual(len(my_data["reports"]), 1)

if __name__ == "__main__":
    unittest.main()
