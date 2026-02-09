"""
Locust load test for telemetry API.

Install:
    pip install locust

Run with web UI:
    cd telemetry/loadtest
    locust --host=https://localhost:8080

Run headless (CI/CD):
    locust --host=https://localhost:8080 \
           --headless \
           --users 50 \
           --spawn-rate 10 \
           --run-time 60s

Environment variables:
    KEYCLOAK_URL      - Keycloak URL (default: https://localhost:8443)
    KEYCLOAK_REALM    - Realm name (default: myrealm)
    KEYCLOAK_CLIENT   - Client ID (default: myclient)
    KEYCLOAK_USERNAME - Test user
    KEYCLOAK_PASSWORD - Test password
"""

import os
import time
import random
import urllib3
from datetime import datetime, timezone

from locust import HttpUser, task, between, events

# Disable SSL warnings for local dev
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def get_env(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


class TelemetryUser(HttpUser):
    """Simulates GPS devices sending track points."""

    wait_time = between(0.1, 0.5)  # Wait 100-500ms between requests

    def on_start(self):
        """Get auth token before starting."""
        self.token = self._get_token()
        self.container_id = f"LOAD{random.randint(1000, 9999)}"

    def _get_token(self) -> str:
        keycloak_url = get_env("KEYCLOAK_URL", "https://localhost:8443")
        realm = get_env("KEYCLOAK_REALM", "myrealm")
        client_id = get_env("KEYCLOAK_CLIENT", "myclient")
        username = get_env("KEYCLOAK_USERNAME")
        password = get_env("KEYCLOAK_PASSWORD")

        if not username or not password:
            raise ValueError("KEYCLOAK_USERNAME and KEYCLOAK_PASSWORD required")

        token_url = f"{keycloak_url}/auth/realms/{realm}/protocol/openid-connect/token"

        # Use requests directly (not locust client) for token
        import requests

        resp = requests.post(
            token_url,
            data={
                "grant_type": "password",
                "client_id": client_id,
                "username": username,
                "password": password,
            },
            verify=False,
        )
        resp.raise_for_status()
        return resp.json()["access_token"]

    def _generate_points(self, count: int) -> list:
        """Generate realistic GPS track points."""
        base_lat = 25.0 + random.uniform(-0.1, 0.1)
        base_lon = 121.0 + random.uniform(-0.1, 0.1)

        points = []
        for i in range(count):
            points.append(
                {
                    "container_id": self.container_id,
                    "lat": base_lat + i * 0.001,
                    "lon": base_lon + i * 0.001,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "speed": random.uniform(0, 80),
                }
            )
        return points

    @task(10)
    def send_single_point(self):
        """Send a single track point (most common)."""
        points = self._generate_points(1)
        self.client.post(
            "/api/track",
            json=points,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            verify=False,
        )

    @task(5)
    def send_small_batch(self):
        """Send 3-5 points (device buffer flush)."""
        points = self._generate_points(random.randint(3, 5))
        self.client.post(
            "/api/track",
            json=points,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            verify=False,
        )

    @task(1)
    def send_large_batch(self):
        """Send 10-20 points (offline device reconnect)."""
        points = self._generate_points(random.randint(10, 20))
        self.client.post(
            "/api/track",
            json=points,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            verify=False,
        )


class HighThroughputUser(HttpUser):
    """Aggressive user for max throughput testing."""

    wait_time = between(0, 0.01)  # Minimal wait

    def on_start(self):
        self.token = self._get_token()
        self.container_id = f"FAST{random.randint(1000, 9999)}"

    def _get_token(self) -> str:
        keycloak_url = get_env("KEYCLOAK_URL", "https://localhost:8443")
        realm = get_env("KEYCLOAK_REALM", "myrealm")
        client_id = get_env("KEYCLOAK_CLIENT", "myclient")
        username = get_env("KEYCLOAK_USERNAME")
        password = get_env("KEYCLOAK_PASSWORD")

        import requests

        resp = requests.post(
            f"{keycloak_url}/auth/realms/{realm}/protocol/openid-connect/token",
            data={
                "grant_type": "password",
                "client_id": client_id,
                "username": username,
                "password": password,
            },
            verify=False,
        )
        resp.raise_for_status()
        return resp.json()["access_token"]

    @task
    def send_batch(self):
        points = [
            {
                "container_id": self.container_id,
                "lat": 25.0 + random.uniform(-0.1, 0.1),
                "lon": 121.0 + random.uniform(-0.1, 0.1),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "speed": random.uniform(0, 80),
            }
            for _ in range(5)
        ]
        self.client.post(
            "/api/track",
            json=points,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            verify=False,
        )


# Print stats at the end
@events.quitting.add_listener
def print_stats(environment, **kwargs):
    stats = environment.stats.total
    print("\n" + "=" * 50)
    print("FINAL RESULTS")
    print("=" * 50)
    print(f"Requests:     {stats.num_requests}")
    print(f"Failures:     {stats.num_failures}")
    print(f"Median:       {stats.median_response_time}ms")
    print(f"P95:          {stats.get_response_time_percentile(0.95)}ms")
    print(f"P99:          {stats.get_response_time_percentile(0.99)}ms")
    print(f"RPS:          {stats.total_rps:.2f}")
    print("=" * 50)
