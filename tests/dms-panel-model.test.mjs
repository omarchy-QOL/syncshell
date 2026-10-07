import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const model = vm.createContext({});
vm.runInContext(readFileSync(new URL(
  "../hosts/dankmaterialshell/models/PanelModel.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\n/, ""), model);
const folders = [
  { id: "z", label: "Documents", path: "/work/docs", status: { state: "idle" } },
  { id: "a", label: "Documents", path: "/home/docs", status: { state: "idle" } },
  { id: "busy", label: "Uploads", status: { state: "syncing" } },
  { id: "error", label: "Broken", status: { state: "idle", pullErrors: 1 } },
  { id: "paused", label: "Archive", paused: true, status: { state: "idle" } },
  { id: "unknown", label: "Starting", status: {} },
];

test("fuzzy search preserves the Omarchy matcher and existing result order", () => {
  const source = readFileSync(new URL(
    "../hosts/omarchy/ui/SyncshellDropdown.qml", import.meta.url), "utf8");
  const reference = vm.createContext({});
  vm.runInContext(source.match(/^    function matchesSearch\([^]*?^    }/m)[0], reference);
  for (const label of ["Documents", "Archive 2026", "Shared Photos", "", "aabb"]) {
    for (const query of ["dcm", "  DOC  ", "ar26", "s p", "", "bbb", "nope"])
      assert.equal(model.matchesSearch(label, query), reference.matchesSearch(label, query));
  }
  assert.deepEqual(Array.from(model.folderOptions(folders, true, null, "name")
    .filter(row => model.matchesOption(row, "dcm")),
    row => row.value), ["a", "z"]);
  assert.equal(model.matchesOption({ label: "Pictures", value: "photos", description: "/work/trip" }, "wk/t"), true);
});

test("duplicate labels retain distinct IDs and deterministic sorting", () => {
  const rows = model.folderOptions(folders, true, null, "name")
    .filter(row => model.matchesOption(row, "Documents"));
  assert.deepEqual(Array.from(rows, row => row.value), ["a", "z"]);
  assert.equal(model.retainedSelection(folders.slice().reverse(), "a"), "a");
});

test("all five filter groups, search by path and priority sorting", () => {
  for (const [group, ids] of Object.entries({ ready: ["a", "z"], active: ["busy"],
    errors: ["error"], paused: ["paused"], unknown: ["unknown"] })) {
    assert.deepEqual(Array.from(model.folderOptions(folders, true, [group], "name"),
      row => row.value), ids);
  }
  assert.equal(model.folderOptions(folders, true, null, "name")
    .filter(row => model.matchesOption(row, "/work"))[0].value, "z");
  for (const priority of ["active", "errors"])
    assert.equal(model.folderOptions(folders, true, null, priority)[0].group, priority);
  assert.equal(model.folderOptions(folders, true, [], "name").length, 0);
});

test("stale folders never claim ready even with a retained snapshot", () => {
  const rows = model.folderOptions(folders, false, null, "name");
  assert.ok(rows.every(row => row.group === "unknown" && row.status === "UNKNOWN"));
  assert.equal(model.retainedSelection([], "vanished"), "");
});

test("stale device options keep identity but do not claim a current connection", () => {
  const devices = [{ id: "a", name: "Laptop", connected: true },
    { id: "b", name: "Laptop", paused: true }];
  const rows = model.deviceOptions(devices, false);
  assert.deepEqual(Array.from(rows, row => row.value), ["a", "b"]);
  assert.ok(rows.every(row => row.status === "UNKNOWN"));
  assert.equal(model.deviceOptions(devices, true)[0].status, "CONNECTED");
});

test("device search uses the same dropdown matcher for name, ID and address", () => {
  const rows = model.deviceOptions([
    { id: "REMOTE-A", name: "Laptop", address: "tcp://192.0.2.1:22000", connected: true },
    { id: "REMOTE-B", name: "Phone", address: "dynamic", connected: false },
  ], true);
  for (const query of ["ltp", "remote-a", "192.0.2.1"])
    assert.deepEqual(Array.from(rows.filter(row => model.matchesOption(row, query)),
      row => row.value), ["REMOTE-A"]);
  assert.equal(rows.filter(row => model.matchesOption(row, "missing")).length, 0);
  assert.equal(rows.filter(row => model.matchesOption(row, "")).length, 2);
});

test("device cards and selectors share status rules including stale and missing data", () => {
  assert.equal(model.deviceStatus(null, true), "");
  for (const [device, expected] of [
    [{ id: "a", paused: true, connected: true }, "PAUSED"],
    [{ id: "a", connected: true }, "CONNECTED"],
    [{ id: "a", connected: false }, "OFFLINE"],
  ]) {
    assert.equal(model.deviceStatus(device, true), expected);
    assert.equal(model.deviceOptions([device], true)[0].status, expected);
    assert.equal(model.deviceStatus(device, false), "UNKNOWN");
    assert.equal(model.deviceOptions([device], false)[0].status, "UNKNOWN");
  }
});

test("filtering never removes hidden multiselect IDs", () => {
  const draft = ["visible", "hidden"];
  assert.deepEqual(Array.from(model.toggled(draft, "visible")), ["hidden"]);
  assert.deepEqual(draft, ["visible", "hidden"]);
  assert.deepEqual(Array.from(model.removedShares(["visible", "hidden"], ["hidden"])),
    ["visible"]);
});

test("side forms flip at edges and stack only when neither side fits", () => {
  assert.equal(model.sidePlacement(1920, 1400, 440, 360, 12, 16), "left");
  assert.equal(model.sidePlacement(1920, 16, 440, 360, 12, 16), "right");
  assert.equal(model.sidePlacement(700, 100, 440, 360, 12, 16), "stack");
});

test("tall side forms do not stretch the main panel or move its bottom anchor", () => {
  const top = model.paneLayout(400, 600, 900, 100, true, false, 0, 0, 12, 100);
  assert.equal(top.mainHeight, 400);
  assert.equal(top.mainY, 0);
  assert.equal(top.sideY, 100);
  assert.equal(top.height, 700);
  const bottom = model.paneLayout(400, 600, 900, 100, true, false, 1, 500, 12, 100);
  assert.equal(bottom.mainHeight, 400);
  assert.equal(bottom.top + bottom.mainY, 500);
  assert.equal(bottom.mainY + bottom.mainHeight, bottom.height);
  assert.equal(bottom.sideY + bottom.sideHeight, bottom.height);
});

test("vertical bar forms retain the main screen position within usable bounds", () => {
  for (const bar of [2, 3]) {
    const layout = model.paneLayout(400, 600, 900, 150, true, false, bar, 300, 12, 100);
    assert.equal(layout.top + layout.mainY, 300);
    assert.equal(layout.mainHeight, 400);
    assert.ok(layout.top >= 0 && layout.top + layout.height <= 900);
    assert.ok(layout.sideY >= 0 && layout.sideY + layout.sideHeight <= layout.height);
  }
});

test("More grows naturally and stacked forms reserve the main footer", () => {
  const closed = model.paneLayout(400, 600, 900, 100, false, false, 0, 0, 12, 100);
  assert.equal(closed.height, 400);
  const more = model.paneLayout(560, 600, 900, 100, false, false, 0, 0, 12, 100);
  assert.equal(more.height, 560);
  const overflow = model.paneLayout(1200, 600, 900, 100, false, false, 0, 0, 12, 100);
  assert.equal(overflow.height, 900);
  const stack = model.paneLayout(500, 800, 420, 100, true, true, 0, 0, 12, 180);
  assert.equal(stack.height, 420);
  assert.ok(stack.mainHeight >= 180);
  assert.equal(stack.sideY, stack.mainHeight + 12);
});

const controllerSource = readFileSync(new URL(
  "../hosts/dankmaterialshell/controllers/PanelController.qml", import.meta.url), "utf8");

function controller(service) {
  const context = vm.createContext({
    Model: model, service, busy: false, submitting: false, pendingAction: "",
    form: "", draft: {}, originalShareIds: [], confirmation: null, error: "",
    returnFocus: null, selectedFolderId: "a", selectedDeviceId: "REMOTE",
    focusRequested() {},
  });
  context.root = context;
  for (const match of controllerSource.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(match[0], context);
  Object.defineProperty(context, "busy", {
    get: () => context.submitting || service.busy === true,
  });
  return context;
}

test("refresh preserves drafts and device sharing removes only original shares", () => {
  let removed;
  const service = {
    folders, remoteDevices: () => [{ id: "REMOTE" }], device: () => ({ id: "REMOTE" }),
    folderIdsForDevice: () => ["a", "z"],
    removeDeviceFolderShares(id, ids) { removed = Array.from(ids); return true; },
  };
  const panel = controller(service);
  panel.begin("device-folders", { id: "REMOTE", name: "Laptop" });
  panel.toggleDraft("a");
  service.folderIdsForDevice = () => ["a", "z", "newly-shared"];
  panel.reconcile();
  assert.deepEqual(Array.from(panel.draft.ids), ["z", "newly-shared"]);
  panel.submit();
  assert.deepEqual(removed, ["a"]);
  assert.equal(panel.submit(), false);
});

test("confirmation freezes its target and rejects a vanished target", () => {
  let forgotten;
  let exists = true;
  const panel = controller({ folder: () => exists ? {} : null,
    forgetFolder(id) { forgotten = id; return true; } });
  const target = { id: "a", label: "Documents" };
  panel.requestConfirmation("folder.forget", target);
  target.id = "z";
  panel.selectedFolderId = "z";
  assert.equal(panel.confirm(), true);
  assert.equal(forgotten, "a");
  assert.equal(panel.confirm(), false);
  panel.settled("folder.forget", true, {}, null);
  panel.requestConfirmation("folder.forget", { id: "a" });
  exists = false;
  assert.equal(panel.confirm(), false);
  assert.match(panel.error, /no longer exists/);
});

test("missing directory confirmation reuses submitted values, not later edits", () => {
  let added;
  const panel = controller({ requestFolderIdSuggestion() {},
    addFolder(values) { added = values; return true; } });
  panel.begin("add-folder", { folderId: "offer", deviceId: "REMOTE" });
  panel.setDraft("path", "/original");
  panel.submit();
  panel.setDraft("path", "/later-edit");
  panel.settled("folder.add-existing", false, null,
    { code: "path_missing", message: "Directory missing" });
  assert.equal(panel.confirmation.target.path, "/original");
  panel.confirm();
  assert.equal(added.path, "/original");
  assert.equal(added.createDirectory, true);
  assert.deepEqual(Array.from(added.deviceIds), ["REMOTE"]);
});

test("cancel and failure retain form drafts; suggestion cannot overwrite typed ID", () => {
  const panel = controller({ requestFolderIdSuggestion() {}, addFolder() { return true; } });
  panel.begin("add-folder", {});
  panel.setDraft("folderId", "typed-id");
  panel.settled("folder.suggest-id", true, { folderId: "generated-id" }, null);
  assert.equal(panel.draft.folderId, "typed-id");
  panel.setDraft("path", "/keep");
  panel.submit();
  panel.settled("folder.add-existing", false, null, { code: "offline", message: "Offline" });
  assert.equal(panel.form, "add-folder");
  assert.equal(panel.draft.path, "/keep");
  panel.requestConfirmation("folder.add-existing", panel.draft);
  panel.cancelConfirmation();
  assert.equal(panel.confirmation, null);
  assert.equal(panel.draft.path, "/keep");
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
