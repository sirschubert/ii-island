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


class TestSubagents(unittest.TestCase):
    def setUp(self):
        self.started = {}
        self.family = hook.Family()
        self.send("session.execution.started")
        self.send("session.created", "c", parentID="s")

    def send(self, kind, sid="s", **data):
        return hook.event_to_payload({"type": kind, "data": {"sessionID": sid, **data}}, self.started, 1000, self.family)

    def test_subagent_finishing_does_not_end_the_run(self):
        self.assertIsNone(self.send("session.execution.succeeded", "c"))
        self.assertIsNone(self.send("session.execution.failed", "c", error={"message": "x"}))
        self.assertIsNone(self.send("session.execution.interrupted", "c", reason="user"))
        self.assertIn("s", self.started)

    def test_parent_finishing_still_stops(self):
        self.assertEqual(self.send("session.execution.succeeded")["event"], "stop")

    def test_subagent_start_is_silent(self):
        self.assertIsNone(self.send("session.execution.started", "c"))

    def test_subagent_tool_keeps_the_parent_alive(self):
        payload = self.send("session.tool.input.started", "c", name="bash")
        self.assertEqual((payload["event"], payload["sessionId"]), ("tool", "s"))

    def test_subagent_permission_shows_on_the_parent(self):
        asked = self.send("permission.asked", "c")
        replied = self.send("permission.replied", "c", reply="once")
        self.assertEqual((asked["event"], asked["sessionId"]), ("perm", "s"))
        self.assertEqual((replied["event"], replied["sessionId"]), ("start", "s"))

    def test_other_subagent_tool_does_not_hide_an_open_permission(self):
        self.send("session.created", "d", parentID="s")
        self.send("permission.asked", "c")
        self.assertIsNone(self.send("session.tool.input.started", "d", name="bash"))
        self.send("permission.replied", "c", reply="once")
        self.assertIsNotNone(self.send("session.tool.input.started", "d", name="bash"))

    def test_nested_subagent_maps_to_the_top_session(self):
        self.send("session.created", "g", parentID="c")
        self.assertEqual(self.send("permission.asked", "g")["sessionId"], "s")

    def test_v1_created_event_with_info_is_understood(self):
        self.send("session.created", "v", info={"parentID": "s"})
        self.assertIsNone(self.send("session.execution.succeeded", "v"))

    def test_reply_after_the_parent_ended_is_dropped(self):
        self.send("session.execution.interrupted", reason="user")
        self.assertIsNone(self.send("permission.replied", "c", reply="reject"))

    def test_session_without_parent_is_a_normal_run(self):
        self.assertIsNone(self.send("session.created", "n"))
        self.assertEqual(self.send("session.execution.started", "n")["sessionId"], "n")
        self.assertEqual(self.send("session.execution.succeeded", "n")["event"], "stop")

    def test_deleted_subagent_is_forgotten(self):
        self.assertIsNone(self.send("session.deleted", "c"))
        self.assertNotIn("c", self.family.parents)


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
