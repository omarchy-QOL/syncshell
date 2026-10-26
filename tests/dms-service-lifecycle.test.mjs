import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const daemon = readFileSync(new URL("../hosts/dankmaterialshell/DankService.qml",
  import.meta.url), "utf8");
const widget = readFileSync(new URL("../hosts/dankmaterialshell/DankPanel.qml",
  import.meta.url), "utf8");
function method(source, name) {
  const match = source.match(new RegExp(`^([ \\t]*)function ${name}\\([^]*?^\\1}`, "m"));
  assert.ok(match);
  return match[0];
}
function registry() {
  const values = {};
  const listeners = [];
  return {
    getGlobalVar(id, name, fallback) { return values[name] ?? fallback; },
    setGlobalVar(id, name, value) { values[name] = value; listeners.forEach(fn => fn()); },
    listeners,
  };
}
function instance(source, name, data) {
  const context = vm.createContext(data);
  context.root = context;
  vm.runInContext(method(source, name), context);
  return context;
}

for (const order of ["widget-first", "daemon-first"]) {
  test(`${order} publishes one service to multiple widgets without polling`, () => {
    const pluginService = registry();
    const core = { identity: "one worker" };
    const host = instance(daemon, "publish", { pluginId: "syncshell", pluginService,
      service: core, ownsService: false });
    const views = [0, 1].map(() => instance(widget, "resolveService", {
      pluginId: "syncshell", pluginService, service: null, host: null,
    }));
    if (order === "daemon-first") host.publish();
    for (const view of views) {
      view.resolveService();
      pluginService.listeners.push(() => view.resolveService());
    }
    if (order === "widget-first") host.publish();
    const publishedHost = pluginService.getGlobalVar("syncshell", "host");
    assert.equal(publishedHost.service, core);
    assert.ok(views.every(view => view.service === core && view.host === publishedHost));
    pluginService.setGlobalVar("syncshell", "service", null);
    pluginService.setGlobalVar("syncshell", "host", null);
    assert.ok(views.every(view => view.service === null && view.host === null));
    assert.doesNotMatch(widget, /Timer\s*\{/);
    assert.doesNotMatch(widget, /AdapterService\s*\{/);
  });
}

test("foreign same-ID global service is not overwritten", () => {
  const pluginService = registry();
  const foreign = {};
  pluginService.setGlobalVar("syncshell", "service", foreign);
  const host = instance(daemon, "publish", {
    pluginId: "syncshell", pluginService, service: null, ownsService: false,
  });
  host.publish();
  assert.equal(host.ownsService, false);
  assert.match(host.collisionError, /already owns/);
  assert.equal(pluginService.getGlobalVar("syncshell", "service"), foreign);
});

test("outside close retains controller drafts and dismisses transient surfaces", () => {
  const popup = readFileSync(new URL(
    "../hosts/dankmaterialshell/ui/SyncshellPanelPopup.qml", import.meta.url), "utf8");
  const closed = method(popup, "onPopoutClosed");
  assert.doesNotMatch(closed, /closeForm/);
  assert.match(closed, /transientSurfaceTracker.closeAll/);
});

test("closing inactive selectors cannot steal focus from the active one", () => {
  const dropdown = readFileSync(new URL(
    "../hosts/dankmaterialshell/ui/SharedWidgetDropdown.qml", import.meta.url), "utf8");
  let focused = 0;
  const selector = instance(dropdown, "close", {
    opened: false, trigger: { forceActiveFocus() { focused++; } },
  });
  selector.close();
  assert.equal(focused, 0);
  selector.opened = true;
  selector.close();
  assert.equal(selector.opened, false);
  assert.equal(focused, 1);
});

test("returning to a retained confirmation restores Cancel selection", () => {
  const popup = readFileSync(new URL(
    "../hosts/dankmaterialshell/ui/SyncshellPanelPopup.qml", import.meta.url), "utf8");
  let cancelled = 0;
  let formFocused = 0;
  let panelFocused = 0;
  const root = instance(popup, "restoreFocus", {
    parentPopout: { shouldBeVisible: true },
    confirming: true, sideOpen: true,
    confirmLoader: { item: { selectCancel() { cancelled++; } } },
    sidePane: { focusContent() { formFocused++; return true; } },
    forceActiveFocus() { panelFocused++; },
  });
  root.restoreFocus();
  assert.deepEqual([cancelled, formFocused, panelFocused], [1, 0, 0]);
  root.confirming = false;
  root.restoreFocus();
  assert.deepEqual([cancelled, formFocused, panelFocused], [1, 1, 0]);
  root.sideOpen = false;
  root.restoreFocus();
  assert.deepEqual([cancelled, formFocused, panelFocused], [1, 1, 1]);
});

test("connection edits retry even when startup never reached a handshake", () => {
  assert.match(daemon,
    /onConnectionKeyChanged:\s*if\s*\(service\)\s*restartTimer\.restart\(\)/);
});

for (const name of ["SharedWidgetBusyButton", "SharedWidgetSquareActionButton"]) {
  test(`${name} rejects held activation keys even after a fast action settles`, () => {
    const source = readFileSync(new URL(
      `../hosts/dankmaterialshell/ui/${name}.qml`, import.meta.url), "utf8");
    let clicks = 0;
    const button = instance(source, "activateKey", {
      Qt: { Key_Return: 13, Key_Enter: 10, Key_Space: 32 },
      enabled: true, busy: false, clicked() { clicks++; },
    });
    button.activateKey({ key: 13, isAutoRepeat: false });
    assert.equal(clicks, 1);
    button.activateKey({ key: 13, isAutoRepeat: true });
    assert.equal(clicks, 1);
    button.busy = true;
    button.activateKey({ key: 32, isAutoRepeat: false });
    assert.equal(clicks, 1);
    button.busy = false;
    button.enabled = false;
    button.activateKey({ key: 32, isAutoRepeat: false });
    assert.equal(clicks, 1);
  });
}
