import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
const source = readFileSync(new URL("../hosts/dux-shell/ui/SyncshellPanelPopup.qml", import.meta.url), "utf8");
const handler = source.match(/^    function handleKey\(event\) \{[^]*?^    \}/m)[0] + "\nhandleKey";
const Qt = Object.fromEntries(["Escape", "Up", "Down", "Left", "Right", "R", "W", "P", "S", "Q"].map(k => ["Key_" + k, k]));
test("p requests the service toggle on either tab, even with no selection", () => {
  for (const tab of ["folders", "devices"]) {
    for (const selected of [null, { id: "retained", paused: false }]) {
      let toggles = 0;
      const controller = { tab, view: { tab }, folder: selected, device: selected,
        requestServiceToggle() { toggles++; } };
      const root = { Window: { window: { activeFocusItem: null } } };
      const context = vm.createContext({ Qt, controller, root, hasForm: false });
      const run = vm.runInContext(handler, context);
      const event = { key: "P", accepted: false };
      run(event);
      assert.equal(toggles, 1);
      assert.equal(event.accepted, true);
      for (const guard of ["repeat", "busy", "form", "confirmation", "editor"]) {
        toggles = 0;
        controller.busy = guard === "busy";
        controller.form = guard === "form" ? "add-folder" : "";
        context.hasForm = guard === "form";
        controller.confirmation = controller.view.confirmation = guard === "confirmation" ? {} : null;
        root.Window.window.activeFocusItem = guard === "editor" ? { cursorPosition: 1 } : null;
        run({ key: "P", isAutoRepeat: guard === "repeat", accepted: false });
        assert.equal(toggles, 0, guard);
      }
    }
  }
});
