import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
const model = vm.createContext({});
vm.runInContext(readFileSync(new URL("../hosts/caelestia/models/PanelModel.js", import.meta.url), "utf8").replace(/^\.pragma library\n/, ""), model);
// Common parity cases from the DMS behavior fixtures; no host UI is imported.
const folders = [
  { id: "z", label: "Documents", path: "/work/docs", status: { state: "idle" } },
  { id: "a", label: "Documents", path: "/home/docs", status: { state: "idle" } },
  { id: "busy", label: "Uploads", status: { state: "syncing" } },
  { id: "error", label: "Broken", status: { state: "idle", pullErrors: 1 } },
  { id: "paused", label: "Archive", paused: true, status: { state: "idle" } },
  { id: "unknown", label: "Starting", status: {} },
];
const ids = rows => Array.from(rows, row => row.value);
test("fuzzy search matches the current Omarchy behavior", () => {
  const source = readFileSync(new URL("../hosts/omarchy/ui/SyncshellDropdown.qml", import.meta.url), "utf8");
  const reference = vm.createContext({});
  vm.runInContext(source.match(/^    function matchesSearch\([^]*?^    }/m)[0], reference);
  for (const label of ["Documents", "Archive 2026", "Shared Photos", "", "aabb"])
    for (const query of ["dcm", "  DOC  ", "ar26", "s p", "", "bbb", "nope"])
      assert.equal(model.matchesSearch(label, query), reference.matchesSearch(label, query));
});
test("duplicate labels, mixed filters, path search and priority sorting preserve IDs", () => {
  assert.deepEqual(ids(model.options(folders, "dcm", null, "name", true)), ["a", "z"]);
  assert.deepEqual(ids(model.options(folders, "", ["active", "errors"], "active", true)), ["busy", "error"]);
  assert.deepEqual(ids(model.options(folders, "/work", null, "name", true)), ["z"]);
  assert.equal(model.options(folders, "", [], "name", true).length, 0);
  assert.equal(model.selectedId(folders.slice().reverse(), "a"), "a");
});
test("stale state never reports current folder or device status", () => {
  assert.ok(folders.every(f => model.folderState(f, false) === "unknown"));
  assert.equal(model.deviceStatus({ connected: true }, false), "Status unknown");
  assert.equal(model.selectedId([], "gone"), "");
});
test("searching a multiselect does not remove hidden selections", () => {
  assert.deepEqual(Array.from(model.toggle(["a", "hidden"], "a")), ["hidden"]);
});
test("taller side forms preserve the main screen anchor at both vertical edges", () => {
  for (const center of [30, 350, 830]) {
    const closed = model.geometry(400, 400, 0, 0, 0, 1100, 900, center, 12);
    const open = model.geometry(400, 400, 360, 650, 150, 1100, 900, center, 12);
    assert.equal(open.mainHeight, closed.mainHeight);
    assert.equal(open.center - open.height / 2 + open.mainY, closed.center - closed.height / 2 + closed.mainY);
    assert.ok(open.center - open.height / 2 >= 0);
    assert.ok(open.formY >= 0 && open.formY + open.formHeight <= open.height);
  }
});
test("More grows naturally, overflow clamps, and narrow screens stack", () => {
  const geometry = (h, w = 1100, side = 0) => model.geometry(400, h, side, 600, 60, w, 900, 400, 12);
  assert.equal(geometry(300).height, 300);
  assert.equal(geometry(500).height, 500);
  assert.equal(geometry(1500).height, 876);
  assert.equal(geometry(500, 700, 360).stacked, true);
});

test("count-only and state-only errors stay visible with fallback details", () => {
  for (const status of [{ state: "error" }, { state: "idle", pullErrors: 4 },
    { state: "idle", errors: [{ path: "file", error: "denied" }] }]) {
    const folder = { id: "broken", status };
    assert.equal(model.hasErrors(folder), true);
    assert.ok(model.errorDetails(folder).length > 0);
  }
  assert.match(model.errorDetails({ status: { pullErrors: 4 } }), /4 errors.*no error details/s);
  assert.match(model.errorDetails({ status: { errors: [{ path: "file", error: "denied" }] } }), /file: denied/);
  assert.equal(model.errorDetails({ status: { state: "idle" } }), "");
  assert.equal(model.hasErrors(null), false);
});

test("folder presentation preserves state precedence, local-only and remaining bytes", () => {
  const folder = (status, extra = {}) => ({ id: "one", path: "/work/docs", label: "Archive", status, ...extra });
  const cases = [
    [folder({ state: "idle" }), false, "", false, false, "UNKNOWN"],
    [folder({ state: "error" }, { paused: true }), true, "", false, false, "UNLINKED"],
    [folder({ state: "idle", pullErrors: 1 }), true, "", false, false, "ERROR"],
    [folder({ state: "scanning" }), true, "", false, false, "SCANNING"],
    [folder({ state: "scanning", needTotalItems: 2 }), true, "", false, false, "SCAN+SYNC"],
    [folder({ state: "idle" }), true, "", true, true, "SCAN+SYNC"],
    [folder({ state: "syncing" }), true, "", false, false, "SYNCING"],
    [folder({ state: "idle" }), true, "one", false, false, "LINKED"],
    [folder({ state: "idle" }), true, "", false, false, "SYNCED"],
    [folder({}), true, "", false, false, "UNKNOWN"],
  ];
  for (const [f, fresh, linked, activity, scanning, expected] of cases) {
    assert.equal(model.folderStatus(f, fresh, linked, activity, scanning), expected);
    assert.ok(model.stateHelp(expected).startsWith(expected + " · "));
  }
  assert.match(model.folderMeta(folder({ state: "syncing", needTotalItems: 2, needBytes: 2048 }), true, "local", false), /2 items remaining.*2.*KiB.*Archive/);
  assert.match(model.folderMeta(folder({ state: "idle", globalFiles: 3 }, { devices: [{ id: "local" }] }), true, "local", false), /3 files.*local only/);
  assert.match(model.folderMeta(folder({ state: "idle" }), false, "local", false), /^Last reported:/);
});
test("activity is current and belongs to the displayed folder", () => {
  const activity = { folderId: "one", action: "Uploading", detail: "photo.jpg" };
  assert.equal(model.folderActivity({ id: "one" }, true, activity), "Uploading photo.jpg");
  assert.equal(model.folderActivity({ id: "two" }, true, activity), "");
  assert.equal(model.folderActivity({ id: "one" }, false, activity), "");
  assert.equal(model.folderActivity(null, true, activity), "");
});
test("remote share confirmation requires fresh connected unpaused device state", () => {
  for (const remoteState of ["valid", "paused", "unknown", "notSharing"]) {
    const folder = { devices: [{ id: "peer", remoteState }] };
    assert.equal(model.remoteShare(folder, { id: "peer", connected: true }, true), remoteState);
    assert.equal(model.remoteShare(folder, { id: "peer", connected: false }, true), "unknown");
    assert.equal(model.remoteShare(folder, { id: "peer", connected: true, paused: true }, true), "unknown");
    assert.equal(model.remoteShare(folder, { id: "peer", connected: true }, false), "unknown");
  }
});
