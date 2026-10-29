import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const model = vm.createContext({});
vm.runInContext(readFileSync(new URL(
  "../hosts/dux-shell/models/PanelModel.js", import.meta.url), "utf8")
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
    "../hosts/omarchy/ui/SharedWidgetDropdown.qml", import.meta.url), "utf8");
  const reference = vm.createContext({});
  vm.runInContext(source.match(/^    function matchesSearch\([^]*?^    }/m)[0], reference);
  for (const label of ["Documents", "Archive 2026", "Shared Photos", "", "aabb"]) {
    for (const query of ["dcm", "  DOC  ", "ar26", "s p", "", "bbb", "nope"])
      assert.equal(model.matchesSearch(label, query), reference.matchesSearch(label, query));
  }
  assert.deepEqual(Array.from(model.folderOptions(folders, true, null, "name")
    .filter(row => model.matchesOption(row, "dcm")),
    row => row.value), ["a", "z"]);
  assert.deepEqual(Array.from(model.folderOptions(folders, true, null, "name")
    .filter(row => model.matchesOption(row, "dcs")), row => row.label), ["docs", "docs"]);
  assert.equal(model.matchesOption({ label: "Pictures", value: "photos", description: "/work/trip" }, "work/t"), true);
  assert.equal(model.matchesOption({ label: "Pictures", value: "photos", description: "/work/trip" }, "wk/t"), false);
  assert.equal(model.matchesOption({ label: "st-peer", value: "LF5CEEF-4JNYE4Z-ZOJ2J-LGT7ZAB" }, "zzz"), false);
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
    [{ id: "a", connected: false }, "DISCONNECTED"],
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

test("side form windows sit beside the popout at the trigger row", () => {
  const popout = { x: 1100, y: 50, width: 400, height: 560 };
  assert.deepEqual({ ...model.sideWindowPlacement(1536, 864, popout, 360, 380, 200, 12, 16, 50) },
    { side: "left", x: 728, y: 250 });
  assert.deepEqual({ ...model.sideWindowPlacement(1536, 864, { ...popout, x: 16 }, 360, 380, 200, 12, 16, 50) },
    { side: "right", x: 428, y: 250 });
  const low = model.sideWindowPlacement(1536, 864, popout, 360, 700, 500, 12, 16, 50);
  assert.equal(low.y, 864 - 16 - 700);
  const high = model.sideWindowPlacement(1536, 864, { ...popout, y: 0 }, 360, 300, 0, 12, 16, 50);
  assert.equal(high.y, 50);
  const narrow = model.sideWindowPlacement(700, 864, { ...popout, x: 150 }, 360, 300, 100, 12, 16, 50);
  assert.equal(narrow.side, "stack");
  assert.equal(narrow.x, 170);
});

const controllerSource = readFileSync(new URL(
  "../hosts/dux-shell/controllers/PanelController.qml", import.meta.url), "utf8");

function controller(service) {
  const context = vm.createContext({
    Model: model, service, busy: false, submitting: false, pendingAction: "",
    fresh: true, form: "", draft: {}, originalShareIds: [], confirmation: null, error: "",
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
    pendingFolderOffers: () => [{ folderId: "offer", deviceId: "REMOTE" }],
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
  // DMS 2.0 fields echo programmatic text as an edit; an unchanged value is no edit.
  const before = panel.draft;
  panel.setDraft("folderId", "typed-id");
  panel.setDraft("label", "");
  assert.equal(panel.draft, before);
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

test("error details group paths by reason and disclose bounded counts", () => {
  const folder = { status: { pullErrors: 7, errors: [
    { path: "one", error: "denied" }, { path: "two", error: "denied" },
    { path: "three", error: "missing" } ] } };
  const detail = model.errorDetails(folder);
  assert.match(detail, /denied\none\ntwo/);
  assert.match(detail, /missing\nthree/);
  assert.equal(detail.match(/denied/g).length, 1);
  assert.match(detail, /Showing 3 of 7 current errors.*Open Web UI/s);
  assert.equal(model.hasErrors({ status: { state: "error" } }), true);
  assert.equal(model.hasErrors({ status: { errors: [{ error: "missing" }] } }), true);
  assert.match(model.errorDetails({ status: { pullErrors: 4 } }), /no error details.*Showing 0 of 4/s);
  assert.equal(model.errorDetails({ status: { state: "idle" } }), "");
});

test("share descriptions preserve remote acceptance and pause explanations", () => {
  for (const [state, expected] of Object.entries({
    valid: "Remote share confirmed", paused: "Remote folder paused",
    notSharing: "Remote is not sharing back", unknown: "Remote acceptance unconfirmed",
  })) {
    const folder = { devices: [{ id: "peer", remoteState: state }] };
    assert.equal(model.remoteShareDescription(model.remoteShare(folder,
      { id: "peer", connected: true }, true)), expected);
    assert.equal(model.remoteShareDescription(model.remoteShare(folder,
      { id: "peer", connected: true }, false)), "Remote acceptance unconfirmed");
  }
});

test("bar icon and tooltip follow Omarchy precedence without inventing success", () => {
  const base = { phase: "ready", online: true, canControlService: false, lifecycle: {}, installation: { available: true },
    folderProblemCount: 0, syncingFolderCount: 0, refreshing: false, busy: false, currentActivity: {}, summaryText: "Up to date" };
  const s = over => Object.assign({}, base, over);
  assert.equal(model.statusVariant(null), "notify");
  assert.equal(model.statusVariant(s({ canControlService: true, lifecycle: { active: false }, online: false })), "pause");
  assert.equal(model.statusVariant(s({ online: false, phase: "error" })), "notify");
  assert.equal(model.statusVariant(s({ refreshing: true })), "sync");
  assert.equal(model.statusVariant(s({})), "default");
  assert.equal(model.barTooltip(s({})), "Syncthing: Up to date");
  assert.equal(model.barTooltip(s({ refreshing: true })), "Syncthing: Up to date");
  assert.equal(model.barTooltip(s({ syncingFolderCount: 1 })), "Syncthing: Sync in progress...");
  assert.equal(model.barTooltip(s({ installation: { available: false } })), "Syncthing: Syncthing is not installed");
});

test("counts and confirmations match the Omarchy panel", () => {
  const omarchy = vm.createContext({});
  vm.runInContext(readFileSync(new URL("../hosts/omarchy/models/PanelModel.js", import.meta.url), "utf8")
    .replace(/^\.(pragma|import) .*$/gm, ""), omarchy);
  for (const n of [0, 999, 1500, 10000, 153000, 1250000])
    assert.equal(model.formatCount(n), omarchy.formatCount(n));
  const popup = readFileSync(new URL("../hosts/omarchy/ui/SyncshellPanelPopup.qml", import.meta.url), "utf8");
  const remove = model.confirmText("device.remove", { name: "optiplex" });
  assert.equal(remove.title, "Remove optiplex from this device?");
  for (const phrase of ["Folder sharing with it will be ", "removed locally. Local folders and files remain.", "The other device is unchanged."])
    assert.ok(popup.includes(phrase) && (remove.title + " " + remove.message).replace(/\s+/g, " ").includes(phrase.trim()));
  const forget = model.confirmText("folder.forget", { id: "abc", label: "Docs", markerName: ".stfolder" });
  assert.equal(forget.title, "Forget Docs (abc)?");
  assert.match(forget.message, /directory and data files will not be deleted/);
  assert.match(forget.message, /\.stfolder marker/);
  assert.match(popup, /confirmText: root\.controller\.folderConfirmAction === "create" \? "Create and add" : "Yes"/);
  assert.match(popup, /cancelText: root\.controller\.folderConfirmAction === "create" \? "Cancel" : "No"/);
  assert.match(popup, /confirmText: "Yes"\n\s+cancelText: "No"/);
  assert.deepEqual([remove.confirm, remove.destructive, forget.confirm, forget.destructive], ["Yes", true, "Yes", true]);
  const reject = model.confirmText("folder.dismiss-pending", { folderId: "abc", label: "Docs", deviceId: "PEER", deviceName: "peer" });
  assert.equal(reject.title, "Reject folder request for Docs (by peer)?");
  assert.equal(reject.message, "This removes the pending announcement without adding the folder.");
  assert.equal(model.confirmText("folder.pause", { id: "abc", path: "/srv/Docs" }).title, "Unlink Docs (abc)?");
  assert.equal(model.confirmText("folder.pause", { id: "abc", path: "/srv/Docs" }).message,
    "Syncthing will pause synchronization. Its configuration and local files remain.");
  const link = model.confirmText("folder.resume", { id: "abc", path: "/srv/Docs" });
  assert.deepEqual([link.title, link.message, link.confirm, link.cancel],
    ["Link Docs (abc)?", "Syncthing will resume synchronization for this folder.", "Yes", "No"]);
  const create = model.confirmText("folder.add-existing", { path: "/srv/a" });
  assert.deepEqual([create.confirm, create.cancel, create.destructive], ["Create and add", "Cancel", false]);
  assert.equal(remove.cancel, "No");
});

test("folders are named by directory and the configured label joins only transient meta", () => {
  const omarchy = vm.createContext({});
  vm.runInContext(readFileSync(new URL("../hosts/omarchy/models/PanelModel.js", import.meta.url), "utf8")
    .replace(/^\.(pragma|import) .*$/gm, ""), omarchy);
  for (const path of ["/home/iz/Sync-Test", "/home/iz/Sync-Test/", "/"])
    assert.equal(model.folderName({ path, id: "x" }), omarchy.pathLabel(path));
  const folder = { id: "x", label: "Sync Test", path: "/home/iz/Sync-Test",
    devices: [{ id: "remote" }], status: { state: "idle", globalFiles: 3, globalBytes: 138 } };
  assert.equal(model.folderMeta(folder, true, "local", false), "3 files · 138 B");
  assert.equal(model.folderMeta(folder, true, "local", true), "Scanning local changes · Sync Test");
  const big = { id: "x", label: "Sync Test", path: "/p", devices: [{ id: "remote" }],
    status: { state: "idle", globalFiles: 153400, globalBytes: 138 } };
  assert.equal(omarchy.folderMeta({ label: "p", configuredLabel: "Sync Test", sharedDeviceCount: 1,
    globalFiles: 153400, globalBytes: 138 }, false), model.folderMeta(big, true, "local", false));
  assert.equal(model.folderMeta(big, true, "local", false), "153k files · 138 B");
});

test("state colours follow Omarchy's green, yellow, red and muted rules", () => {
  const panel = readFileSync(new URL("../hosts/omarchy/OmarchyPanel.qml", import.meta.url), "utf8");
  const omarchy = { warning: "warning", urgent: "error", success: "success", muted: "onSurfaceVariant" };
  const body = panel.match(/function folderStateColor\(folder\) \{([^]*?)\n    \}/)[1];
  for (const [, state, colour] of body.matchAll(/state === "([^"]+)"\)\s*return ([\w.]+);/g))
    assert.equal(model.folderStateRole(state), omarchy[colour.split(".").pop()], state);
  assert.equal(model.folderStateRole("SYNCED"), "success");
  assert.equal(model.folderStateRole("LINKED"), "success");
  assert.deepEqual(["CONNECTED", "PAUSED", "DISCONNECTED", "UNKNOWN"].map(model.deviceStateRole),
    ["success", "warning", "onSurfaceVariant", "onSurfaceVariant"]);
  assert.deepEqual(["removing", "upload", "sync", ""].map(model.activityRole),
    ["error", "success", "info", "info"]);
});
