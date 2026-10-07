import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, cpSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = fileURLToPath(new URL("..", import.meta.url));
const sourceMap = JSON.parse(readFileSync(join(root,
  "integrations/dankmaterialshell/import-map.json"), "utf8"));

function fixture(t, map) {
  const directory = mkdtempSync(join(tmpdir(), "syncshell-import-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  mkdirSync(join(directory, "shared"));
  const names = ["AdapterService.qml", "CoreProcess.qml", "Paths.js", "RescanTracker.qml"];
  for (const name of names)
    cpSync(join(root, "shared", name), join(directory, "shared", name));
  writeFileSync(join(directory, "files.txt"), names.map(name => `shared/${name}`).join("\n"));
  writeFileSync(join(directory, "map.json"), JSON.stringify(map));
  const run = () => spawnSync(process.execPath, [resolve(root, "integrations/assemble-qml.mjs"),
    directory, join(directory, "files.txt"), join(directory, "map.json")], { encoding: "utf8" });
  return { directory, run };
}

test("DMS preserves explicit relative imports in its packaged tree", t => {
  const { directory, run } = fixture(t, sourceMap);
  assert.equal(run().status, 0);
  assert.equal(readFileSync(join(directory, "shared/AdapterService.qml"), "utf8"),
    readFileSync(join(root, "shared/AdapterService.qml"), "utf8"));
});

test("Caelestia mapping gives shared QML an explicit named self-import", t => {
  const map = { ...sourceMap, '"."': "ilyazar.syncshell.shared" };
  const { directory, run } = fixture(t, map);
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  const generated = readFileSync(join(directory, "shared/AdapterService.qml"), "utf8");
  assert.match(generated, /^import ilyazar\.syncshell\.shared$/m);
  assert.doesNotMatch(generated, /^import "\."$/m);
  assert.equal(generated.replace("import ilyazar.syncshell.shared", 'import "."'),
    readFileSync(join(root, "shared/AdapterService.qml"), "utf8"));
});

test("undeclared imports fail instead of silently leaking shell APIs", t => {
  const map = { ...sourceMap };
  delete map.Quickshell;
  const { run } = fixture(t, map);
  const result = run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unmapped import/);
});

test("missing packaged imports fail closed", t => {
  const { directory, run } = fixture(t, sourceMap);
  rmSync(join(directory, "shared/Paths.js"));
  assert.notEqual(run().status, 0);
});
