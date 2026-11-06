import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL(
  "../hosts/dux-shell/controllers/ThemePaletteController.qml",
  import.meta.url), "utf8");

function theme() {
  const writes = [];
  const context = vm.createContext({
    selection: "dms", palette: { accent: "#aabbcc" }, key: "current",
    pendingKey: "", pendingSelection: "", error: "", dirty: false, paletteOnly: false,
    initialized: true, debounce: { restart() {} },
    service: {
      online: true, busy: false, refreshing: false,
      webUi: { theme: "syncshell-dms-themed" },
      applyWebProfile(style, palette) { writes.push({ style, palette }); return true; },
      setWebUiTheme(style) { writes.push({ style }); return true; },
    },
  });
  context.root = context;
  Object.defineProperty(context, "busy", { get: () => context.pendingKey !== "" });
  for (const match of source.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(match[0], context);
  vm.runInContext(source.match(/^        function onActionFinished\([^]*?^        }/m)[0], context);
  const changed = source.match(/^    onPaletteChanged: (\{[^]*?^    \})/m)[1];
  const paletteChanged = vm.runInContext("(() => " + changed + ")", context);
  return { context, writes, paletteChanged };
}

test("queued palette work cannot reselect a profile after ownership changes", () => {
  for (const selected of ["default", "syncshell-dms-modern", "syncshell-caelestia-themed"]) {
    const { context, writes, paletteChanged } = theme();
    paletteChanged();
    assert.equal(context.dirty, true);
    context.service.webUi.theme = selected;
    context.apply();
    assert.equal(writes.length, 0, selected);
    assert.equal(context.dirty, false);
  }
});

test("an explicit selection still applies when a palette change is also queued", () => {
  const { context, writes, paletteChanged } = theme();
  context.schedule();
  paletteChanged();
  context.service.webUi.theme = "default";
  context.apply();
  assert.equal(writes.length, 1);
  assert.equal(writes[0].style, "themed");
  assert.equal(writes[0].palette.accent, "#aabbcc");
});

test("palette work waits for busy work and uses the newest palette", () => {
  const { context, writes, paletteChanged } = theme();
  paletteChanged();
  context.service.busy = true;
  context.apply();
  assert.equal(writes.length, 0);
  assert.equal(context.dirty, true);
  context.palette = { accent: "#123456" };
  context.service.busy = false;
  context.apply();
  assert.equal(writes.length, 1);
  assert.equal(writes[0].palette.accent, "#123456");
  assert.equal(context.dirty, false);
});

test("other profiles do not queue palette work", () => {
  for (const selected of ["default", "syncshell-dms-modern", "syncshell-caelestia-themed"]) {
    const { context, writes, paletteChanged } = theme();
    context.service.webUi.theme = selected;
    paletteChanged();
    context.apply();
    assert.equal(context.dirty, false);
    assert.equal(writes.length, 0);
  }
});

test("a changed palette during profile application stays an automatic update", () => {
  const { context, writes } = theme();
  context.schedule();
  context.apply();
  assert.equal(writes.length, 1);
  context.key = "new palette";
  context.service.webUi.theme = "syncshell-caelestia-themed";
  context.onActionFinished("webui.apply-profile", true, {}, null);
  context.apply();
  assert.equal(writes.length, 1);
  assert.equal(context.dirty, false);
});

test("explicit selection changes during application still settle to the new choice", () => {
  const { context, writes } = theme();
  context.schedule();
  context.apply();
  context.selection = "modern";
  context.key = "modern";
  context.schedule();
  context.onActionFinished("webui.apply-profile", true, {}, null);
  context.apply();
  assert.equal(writes.length, 2);
  assert.equal(writes[1].style, "modern");
});
