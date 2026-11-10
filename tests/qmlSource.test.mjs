// Source-level guards for mistakes the QML engine only reports at runtime, when the
// broken line finally executes (a rain card, a click), so a clean startup proves nothing.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const src = join(dirname(fileURLToPath(import.meta.url)), "..", "src");
const qmlFiles = readdirSync(src, { recursive: true })
    .filter((f) => f.endsWith(".qml"))
    .map((f) => join(src, f));

function stripComments(text) {
    return text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "");
}

test("every file using an island singleton imports qs.modules.island", () => {
    const missing = qmlFiles.filter((file) => {
        const text = stripComments(readFileSync(file, "utf8"));
        return /\bIsland(State|Config)\./.test(text) && !/^import qs\.modules\.island\s*$/m.test(text);
    });
    assert.deepEqual(missing.map((f) => relative(src, f)), []);
});

test("window focus uses Lua dispatch syntax (Hyprland 0.55+ rejects the old form)", () => {
    const legacy = qmlFiles.filter((file) => /"dispatch",\s*"focuswindow"/.test(readFileSync(file, "utf8")));
    assert.deepEqual(legacy.map((f) => relative(src, f)), []);
});
