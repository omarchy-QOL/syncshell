import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const panel = readFileSync(new URL(
  "../hosts/omarchy/OmarchyPanel.qml", import.meta.url), "utf8");
const handler = panel.match(/^\s*onPressed:\s*([^\n]+)/m);
assert.ok(handler, "bar button press handler exists");

for (const [name, button] of [["left", 1], ["right", 2]]) {
  test(`${name} click toggles the panel without refreshing`, () => {
    let opened = false;
    let refreshes = 0;
    const press = vm.runInNewContext(
      `(buttonCode) => { ${handler[1]}; }`, {
        root: {
          toggle() { opened = !opened; },
          syncthing: { refresh() { refreshes++; } },
        },
        Qt: { LeftButton: 1, RightButton: 2 },
      });
    press(button);
    assert.equal(opened, true);
    press(button);
    assert.equal(opened, false);
    assert.equal(refreshes, 0);
  });
}
