import os
import sys
import unittest
from datetime import datetime, timezone, timedelta

# Ensure python_ai directory is in path
sys.path.insert(0, os.path.abspath('lib/python_ai'))

import api

class TestTripSharingAPI(unittest.TestCase):
    def setUp(self):
        api.app.config['TESTING'] = True
        self.client = api.app.test_client()
        api.init_feedback_db()

    def test_01_create_share_validation(self):
        # Missing destination
        res = self.client.post('/api/trip/create_share', json={})
        self.assertEqual(res.status_code, 400)
        self.assertIn("destination is required", res.get_json()['error'])

        # Invalid coordinates
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Marina Beach",
            "latitude": 999.0,
            "longitude": 80.0
        })
        self.assertEqual(res.status_code, 400)

        # Successful creation
        res = self.client.post('/api/trip/create_share', json={
            "origin": "Chennai Central",
            "destination": "Marina Beach",
            "vehicle": "Car",
            "eta_minutes": 25,
            "latitude": 13.0827,
            "longitude": 80.2707,
            "heading": 90.0,
            "speed": 10.5,
            "accuracy": 12.0
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertIn('share_token', data)
        self.assertIn('update_token', data)
        self.assertEqual(data['status'], 'active')
        self.assertEqual(data['destination'], 'Marina Beach')

    def test_02_update_location_and_authorization(self):
        # Create a session
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Besant Nagar",
            "latitude": 13.0000,
            "longitude": 80.2500
        })
        tokens = res.get_json()
        share_tok = tokens['share_token']
        upd_tok = tokens['update_token']

        # Unauthorized update (wrong token)
        res_unauth = self.client.post('/api/trip/update_location', json={
            "update_token": "invalid_token_12345",
            "latitude": 13.0010,
            "longitude": 80.2510
        })
        self.assertEqual(res_unauth.status_code, 404)

        # Unauthorized update (using public share_token instead of update_token)
        res_share_tok = self.client.post('/api/trip/update_location', json={
            "update_token": share_tok,
            "latitude": 13.0010,
            "longitude": 80.2510
        })
        self.assertEqual(res_share_tok.status_code, 404)

        # Authorized update
        res_ok = self.client.post('/api/trip/update_location', json={
            "update_token": upd_tok,
            "latitude": 13.0020,
            "longitude": 80.2520,
            "heading": 145.0,
            "speed": 14.0,
            "accuracy": 8.0,
            "eta_minutes": 18
        })
        self.assertEqual(res_ok.status_code, 200)
        self.assertTrue(res_ok.get_json()['success'])

        # Read back via public status endpoint
        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        self.assertEqual(res_status.status_code, 200)
        status_data = res_status.get_json()
        self.assertEqual(status_data['status'], 'active')
        self.assertAlmostEqual(status_data['latitude'], 13.0020)
        self.assertAlmostEqual(status_data['longitude'], 80.2520)
        self.assertEqual(status_data['eta_minutes'], 18)
        self.assertFalse(status_data['is_stale'])

    def test_03_pause_and_resume(self):
        res = self.client.post('/api/trip/create_share', json={"destination": "Guindy"})
        upd_tok = res.get_json()['update_token']
        share_tok = res.get_json()['share_token']

        # Update to paused
        self.client.post('/api/trip/update_location', json={
            "update_token": upd_tok,
            "latitude": 13.0067,
            "longitude": 80.2000,
            "status": "paused"
        })
        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        self.assertEqual(res_status.get_json()['status'], 'paused')

        # Resume to active
        self.client.post('/api/trip/update_location', json={
            "update_token": upd_tok,
            "latitude": 13.0070,
            "longitude": 80.2010,
            "status": "active"
        })
        res_status2 = self.client.get(f'/api/trip/status/{share_tok}')
        self.assertEqual(res_status2.get_json()['status'], 'active')

    def test_04_stop_sharing_clears_precise_location(self):
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Tambaram",
            "latitude": 12.9249,
            "longitude": 80.1000
        })
        upd_tok = res.get_json()['update_token']
        share_tok = res.get_json()['share_token']

        # Stop sharing
        res_stop = self.client.post('/api/trip/stop_sharing', json={"update_token": upd_tok})
        self.assertEqual(res_stop.status_code, 200)
        self.assertEqual(res_stop.get_json()['status'], 'stopped')

        # Status check: coordinates must NOT be exposed
        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        data = res_status.get_json()
        self.assertEqual(data['status'], 'stopped')
        self.assertIsNone(data.get('latitude'))
        self.assertIsNone(data.get('longitude'))
        self.assertIn("stopped by the user", data['message'])

        # Further updates must be rejected
        res_upd = self.client.post('/api/trip/update_location', json={
            "update_token": upd_tok,
            "latitude": 12.9300,
            "longitude": 80.1050
        })
        self.assertEqual(res_upd.status_code, 400)

    def test_05_complete_trip_safe_arrival(self):
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Airport Terminal",
            "latitude": 12.9850,
            "longitude": 80.1650
        })
        upd_tok = res.get_json()['update_token']
        share_tok = res.get_json()['share_token']

        # Complete trip
        res_comp = self.client.post('/api/trip/complete_trip', json={"update_token": upd_tok})
        self.assertEqual(res_comp.status_code, 200)
        self.assertEqual(res_comp.get_json()['status'], 'completed')
        self.assertIn("Airport Terminal", res_comp.get_json()['message'])

        # Public viewer status
        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        data = res_status.get_json()
        self.assertEqual(data['status'], 'completed')
        self.assertIn("Arrived safely", data['message'])

    def test_06_stale_location_detection(self):
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Vadapalani",
            "latitude": 13.0500,
            "longitude": 80.2100
        })
        upd_tok = res.get_json()['update_token']
        share_tok = res.get_json()['share_token']

        # Manually backdate updated_at in DB by 3 minutes (180 seconds)
        past_iso = (datetime.now(timezone.utc) - timedelta(seconds=180)).isoformat()
        with api.sqlite3.connect(api.FEEDBACK_DB_PATH) as conn:
            conn.execute("UPDATE live_shared_trips SET updated_at = ? WHERE update_token = ?", (past_iso, upd_tok))
            conn.commit()

        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        data = res_status.get_json()
        self.assertEqual(data['status'], 'active')
        self.assertTrue(data['is_stale'])
        self.assertGreaterEqual(data['stale_seconds'], 170)

    def test_07_expired_session(self):
        res = self.client.post('/api/trip/create_share', json={
            "destination": "Koyambedu",
            "latitude": 13.0694,
            "longitude": 80.1948
        })
        upd_tok = res.get_json()['update_token']
        share_tok = res.get_json()['share_token']

        # Manually expire session
        past_exp = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
        with api.sqlite3.connect(api.FEEDBACK_DB_PATH) as conn:
            conn.execute("UPDATE live_shared_trips SET expires_at = ? WHERE update_token = ?", (past_exp, upd_tok))
            conn.commit()

        # Update should fail with 410
        res_upd = self.client.post('/api/trip/update_location', json={
            "update_token": upd_tok,
            "latitude": 13.0700,
            "longitude": 80.1950
        })
        self.assertEqual(res_upd.status_code, 410)

        # Status check shows expired with no coordinates
        res_status = self.client.get(f'/api/trip/status/{share_tok}')
        data = res_status.get_json()
        self.assertEqual(data['status'], 'expired')
        self.assertIsNone(data.get('latitude'))

if __name__ == '__main__':
    unittest.main()