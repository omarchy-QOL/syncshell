import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
const source = readFileSync(new URL("../hosts/caelestia/CaelestiaService.qml", import.meta.url), "utf8");
function registry() {
  const context = vm.createContext({});
  vm.runInContext(readFileSync(new URL("../hosts/caelestia/models/Ownership.js", import.meta.url), "utf8").replace(/^\.pragma library\n/, ""), context);
  return context;
}
function owner(ownership) {
  let running = false, starts = 0, stops = 0;
  const service = vm.createContext({
    plugin: null, settings: null, ownerGeneration: -1, predecessor: null,
    owners: [], retired: false, awaitingExit: false, views: {}, Ownership: ownership,
    paletteUpdate: { stop() {} }, Qt: { callLater(fn) { fn(); } },
    adapter: { core: {
      get running() { return running; },
      desiredRunning: false,
      start() { this.desiredRunning = true; running = true; starts++; },
      terminate() { this.desiredRunning = false; stops++; },
    } },
  });
  service.root = service;
  Object.defineProperty(service, "eligible", { get() {
    return !!service.plugin && service.plugin.enabled && !service.retired
      && service.plugin.generation === service.ownerGeneration && service.owners.length > 0;
  } });
  for (const match of source.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(match[0], service);
  return { service, counts: () => ({ starts, stops }), exit() { running = false; } };
}
test("two bars share ownership and final release requests shutdown", () => {
  const host = owner(registry());
  const plugin = { enabled: true, generation: 1 };
  host.service.acquire({ plugin }, {}, "monitor-a");
  host.service.acquire({ plugin }, {}, "monitor-b");
  host.service.release("monitor-a");
  assert.equal(host.counts().stops, 0);
  assert.equal(host.counts().starts, 1);
  host.service.release("monitor-b");
  assert.equal(host.counts().stops, 1);
  assert.equal(host.service.owners.length, 0);
});
test("a new QML generation waits for the previous worker exit", () => {
  const shared = registry(), old = owner(shared), next = owner(shared);
  const plugin = { enabled: true, generation: 1 };
  old.service.acquire({ plugin }, {}, "old");
  plugin.generation = 2;
  next.service.acquire({ plugin }, {}, "new");
  assert.equal(old.service.retired, true);
  assert.equal(next.counts().starts, 0);
  old.exit();
  next.service.maybeStart();
  assert.equal(next.counts().starts, 1);
});
test("a disabled or released generation cannot restart", () => {
  const host = owner(registry()), plugin = { enabled: true, generation: 1 };
  host.service.acquire({ plugin }, {}, "bar");
  host.service.release("bar"); host.exit(); host.service.maybeStart();
  assert.equal(host.counts().starts, 1);
  plugin.enabled = false;
  host.service.acquire({ plugin }, {}, "new");
  assert.equal(host.counts().starts, 1);
});
test("explicit termination cancels scheduled crash recovery", () => {
  const code = readFileSync(new URL("../shared/CoreProcess.qml", import.meta.url), "utf8");
  const context = vm.createContext({
    restartTimer: { stop() { context.recoveryStopped = true; } },
    shutdownTimer: { stop() {} }, coreProcess: { running: false },
    _restartRequested: true, _expectedStop: false, desiredRunning: true,
  });
  vm.runInContext(code.match(/^    function terminate\([^]*?^    }/m)[0], context);
  context.terminate();
  assert.equal(context.recoveryStopped, true);
  assert.equal(context._expectedStop, true);
  assert.equal(context.desiredRunning, false);
});

test("only the current eligible owner can request a Web UI profile", () => {
  for (const inactive of ["disabled", "released", "retired", "replaced"]) {
    const host = owner(registry()), plugin = { enabled: true, generation: 1 };
    let writes = 0;
    host.service.theme = { palette: { accent: "#aabbcc" } };
    host.service.adapter.applyWebProfile = () => { writes++; return true; };
    host.service.adapter.setWebUiTheme = () => { writes++; return true; };
    host.service.acquire({ plugin }, {}, "bar");
    assert.equal(host.service.applyWebUi("themed"), true);
    assert.equal(writes, 1);
    if (inactive === "disabled") plugin.enabled = false;
    if (inactive === "released") host.service.release("bar");
    if (inactive === "retired") host.service.retire();
    if (inactive === "replaced") plugin.generation++;
    assert.equal(host.service.applyWebUi("themed"), false, inactive);
    assert.equal(host.service.applyWebUi("default"), false, inactive);
    assert.equal(writes, 1, inactive);
  }
});
