import importlib.util
import io
import os
import tempfile
import time
import unittest

HOOK_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "hooks",
    "claude-island-hook.py",
)

_spec = importlib.util.spec_from_file_location("claude_island_hook", HOOK_PATH)
hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hook)


class TestHook(unittest.TestCase):
    def test_pretooluse_bash(self):
        data = {
            "hook_event_name": "PreToolUse",
            "session_id": "s",
            "cwd": "/x",
            "tool_name": "Bash",
            "tool_input": {"command": "hyprctl reload"},
        }
        payload = hook.build_payload(data, {}, 0)
        self.assertEqual(payload["event"], "tool")
        self.assertEqual(payload["sessionId"], "s")
        self.assertEqual(payload["cwd"], "/x")
        self.assertEqual(payload["tool"], "Bash")
        self.assertEqual(payload["detail"], "hyprctl reload")

    def test_notification_permission(self):
        data = {
            "hook_event_name": "Notification",
            "session_id": "s",
            "cwd": "/x",
            "message": "Claude needs your permission to use Bash",
        }
        payload = hook.build_payload(data, {}, 0)
        self.assertEqual(payload["event"], "perm")

    def test_idle_notification_ignored(self):
        data = {
            "hook_event_name": "Notification",
            "session_id": "s",
            "cwd": "/x",
            "message": "Claude is waiting for your input",
        }
        self.assertIsNone(hook.build_payload(data, {}, 0))

    def test_stop_elapsed(self):
        data = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x"}
        payload = hook.build_payload(data, {"startMs": 1000}, 191000)
        self.assertEqual(payload["event"], "stop")
        self.assertEqual(payload["elapsedMs"], 190000)

    def test_stop_summary_from_last_message(self):
        h = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x",
             "last_assistant_message": "Fixed the island position. It now sits in the bar.\n\nDetails follow."}
        p = hook.build_payload(h, {}, 0)
        self.assertEqual(p["summary"], "Fixed the island position.")

    def test_stop_summary_from_transcript(self):
        import tempfile, json as _j
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
            f.write(_j.dumps({"type": "user", "message": {"role": "user", "content": "hi"}}) + "\n")
            f.write(_j.dumps({"type": "assistant", "message": {"role": "assistant", "content": [
                {"type": "text", "text": "**Done:** the carousel now browses sources without switching the active one, which was the bug."}]}}) + "\n")
            path = f.name
        h = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x", "transcript_path": path}
        p = hook.build_payload(h, {}, 0)
        self.assertTrue(p["summary"].startswith("Done: the carousel now browses"))
        self.assertLessEqual(len(p["summary"]), 72)
        self.assertNotIn("*", p["summary"])

    def test_stop_without_text_has_no_summary(self):
        p = hook.build_payload({"hook_event_name": "Stop", "session_id": "s"}, {}, 0)
        self.assertNotIn("summary", p)

    def test_find_terminal_pid(self):
        parents = {500: 400, 400: 300, 300: 1}
        calls = []

        def read_ppid(pid):
            calls.append(pid)
            return parents.get(pid)

        # Match: 300 is a client pid in the ancestor chain.
        self.assertEqual(hook.find_terminal_pid(500, {300}, read_ppid), 300)

        # No match: chain reaches pid 1 without hitting a client.
        self.assertIsNone(hook.find_terminal_pid(500, set(), read_ppid))

        # Cycle guard: a parent loop must stop after at most 64 hops.
        calls.clear()

        def cyclic_ppid(pid):
            calls.append(pid)
            return 6 if pid == 5 else 5

        self.assertIsNone(hook.find_terminal_pid(5, set(), cyclic_ppid))
        self.assertLessEqual(len(calls), 64)

    def test_qs_missing_exits_zero_fast(self):
        with tempfile.TemporaryDirectory() as empty_bin, \
                tempfile.TemporaryDirectory() as runtime:
            env = {"PATH": empty_bin, "XDG_RUNTIME_DIR": runtime}
            stdin = io.StringIO(
                '{"hook_event_name":"PreToolUse","session_id":"s","cwd":"/x",'
                '"tool_name":"Bash","tool_input":{"command":"ls"}}'
            )
            start = time.monotonic()
            rc = hook.main(stdin, env)
            elapsed = time.monotonic() - start
        self.assertEqual(rc, 0)
        self.assertLess(elapsed, 0.3)

    def test_garbage_stdin(self):
        with tempfile.TemporaryDirectory() as runtime:
            env = {"PATH": os.environ.get("PATH", ""), "XDG_RUNTIME_DIR": runtime}
            self.assertEqual(hook.main(io.StringIO("not json"), env), 0)


if __name__ == "__main__":
    unittest.main()
