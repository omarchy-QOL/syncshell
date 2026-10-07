import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL(
  "../hosts/dankmaterialshell/controllers/SettingsController.qml", import.meta.url), "utf8");
const defaults = source.match(/readonly property var defaults:\s*(\(\{[^]*?^\s*\}\))/m);
assert.ok(defaults);

function settings(data = {}) {
  const writes = [];
  const context = vm.createContext({
    owner: "omarchy-QOL/syncshell", pluginId: "syncshell", pluginData: data,
    pluginService: { savePluginData: (...args) => writes.push(args) },
  });
  context.root = context;
  context.defaults = vm.runInContext(defaults[1], context);
  for (const match of source.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(match[0], context);
  Object.defineProperties(context, {
    valid: { get: () => context.validate(context.pluginData) === "" },
    values: { get: () => ({ ...context.defaults, ...context.pluginData.syncshell }) },
  });
  return { context, writes };
}

test("new settings default to unprivileged service control", () => {
  const { context } = settings();
  assert.equal(context.valid, true);
  assert.equal(context.defaults.lifecycleAuthorized, false);
  assert.equal(context.defaults.webUiTheme, "default");
});

test("foreign or unsupported settings are rejected without writes", () => {
  for (const data of [
    { refreshIntervalSec: 60 },
    { syncshell: { schema: 2, owner: "omarchy-QOL/syncshell" } },
    { syncshell: { schema: 1, owner: "another-port" } },
    { syncshell: { schema: 1, owner: "omarchy-QOL/syncshell", unexpected: true } },
  ]) {
    const { context, writes } = settings(data);
    assert.equal(context.valid, false);
    assert.equal(context.save("iconStyle", "branded"), false);
    assert.deepEqual(writes, []);
  }
});

test("settings updates write one owned object and reject invalid values", () => {
  const { context, writes } = settings({ enabled: true });
  for (const [key, value] of [
    ["probeIntervalSeconds", 0], ["probeIntervalSeconds", 1.5],
    ["refreshIntervalSeconds", 3601], ["webUiTheme", "unknown"],
    ["iconStyle", "unknown"], ["desiredServiceState", "start"],
  ]) {
    assert.equal(context.save(key, value), false);
  }
  assert.equal(writes.length, 0);
  assert.equal(context.save("iconStyle", "branded"), true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0][0], "syncshell");
  assert.equal(writes[0][1], "syncshell");
  assert.equal(writes[0][2].schema, 1);
  assert.equal(writes[0][2].owner, "omarchy-QOL/syncshell");
  assert.equal(writes[0][2].iconStyle, "branded");
});

test("lifecycle authorization requires an exact safe unit", () => {
  const { context } = settings();
  assert.notEqual(context.validate({ syncshell: { ...context.defaults,
    lifecycleAuthorized: true, lifecycleUnit: "syncthing*" } }), "");
  assert.equal(context.validate({ syncshell: { ...context.defaults,
    lifecycleAuthorized: true, lifecycleUnit: "syncthing.service" } }), "");
});
