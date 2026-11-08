import importlib.util
import json
import os
import tempfile
import unittest

HOOK_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "hooks",
    "opencode-island-hook.py",
)

_spec = importlib.util.spec_from_file_location("opencode_island_hook", HOOK_PATH)
hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hook)


def event(kind, **data):
    return {"type": kind, "data": {"sessionID": "s", **data}}


class TestRouting(unittest.TestCase):
    def test_started_is_live(self):
        payload = hook.event_to_payload(event("session.execution.started"), {}, 1000)
        self.assertEqual(payload["event"], "start")
        self.assertEqual(payload["sessionId"], "s")

    def test_tool_name_comes_from_input_started(self):
        payload = hook.event_to_payload(event("session.tool.input.started", name="bash"), {}, 0)
        self.assertEqual(payload["event"], "tool")
        self.assertEqual(payload["tool"], "bash")

    def test_success_stops_with_elapsed_and_forgets_session(self):
        started = {}
        hook.event_to_payload(event("session.execution.started"), started, 1000)
        payload = hook.event_to_payload(event("session.execution.succeeded"), started, 4000)
        self.assertEqual(payload["event"], "stop")
        self.assertEqual(payload["elapsedMs"], 3000)
        self.assertNotIn("failed", payload)
        self.assertEqual(started, {})

    def test_interrupted_ends_quietly(self):
        payload = hook.event_to_payload(event("session.execution.interrupted", reason="user"), {}, 0)
        self.assertEqual(payload["event"], "end")

    def test_permission_asked_then_replied(self):
        asked = hook.event_to_payload(event("permission.asked"), {}, 0)
        replied = hook.event_to_payload(event("permission.replied", reply="once"), {}, 0)
        self.assertEqual(asked["event"], "perm")
        self.assertEqual(replied["event"], "start")

    def test_failure_uses_error_message(self):
        payload = hook.event_to_payload(event("session.execution.failed", error={"message": "boom"}), {}, 0)
        self.assertEqual(payload["event"], "stop")
        self.assertTrue(payload["failed"])
        self.assertEqual(payload["summary"], "boom")

    def test_failure_without_details_has_readable_summary(self):
        payload = hook.event_to_payload(event("session.execution.failed", error={}), {}, 0)
        self.assertEqual(payload["summary"], "Opencode run failed")

    def test_unsubscribed_or_sessionless_events_are_ignored(self):
        self.assertIsNone(hook.event_to_payload(event("session.text.delta"), {}, 0))
        self.assertIsNone(hook.event_to_payload({"type": "session.execution.started", "data": {}}, {}, 0))
        self.assertIsNone(hook.event_to_payload({"type": "session.execution.started", "data": "x"}, {}, 0))

    def test_every_route_is_requested_from_the_server(self):
        self.assertEqual(set(hook.subscribed_types()), set(hook.ROUTES))
        self.assertNotIn("session.text.delta", hook.subscribed_types())


class TestSseLine(unittest.TestCase):
    def test_data_line(self):
        self.assertEqual(hook.parse_sse_line(b'data: {"type":"x"}'), {"type": "x"})

    def test_utf8_body(self):
        line = 'data: {"type":"é"}'.encode()
        self.assertEqual(hook.parse_sse_line(line)["type"], "é")

    def test_non_data_and_broken_lines(self):
        self.assertIsNone(hook.parse_sse_line(b""))
        self.assertIsNone(hook.parse_sse_line(b": heartbeat"))
        self.assertIsNone(hook.parse_sse_line(b"event: message"))
        self.assertIsNone(hook.parse_sse_line(b'data: {"type":'))
        self.assertIsNone(hook.parse_sse_line(b"data: [1]"))


class TestLoadService(unittest.TestCase):
    def write(self, directory, content):
        path = os.path.join(directory, "service.json")
        with open(path, "w") as f:
            f.write(content)
        return path

    def test_reads_url_and_password(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.write(d, json.dumps({"url": "http://h:1", "password": "p"}))
            self.assertEqual(hook.load_service(path, {}), ("http://h:1", "p"))

    def test_env_password_when_file_missing_does_not_crash(self):
        with tempfile.TemporaryDirectory() as d:
            result = hook.load_service(os.path.join(d, "nope.json"), {"OPENCODE_PASSWORD": "e"})
            self.assertEqual(result, (hook.DEFAULT_URL, "e"))

    def test_no_credentials(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertIsNone(hook.load_service(os.path.join(d, "nope.json"), {}))


if __name__ == "__main__":
    unittest.main()
