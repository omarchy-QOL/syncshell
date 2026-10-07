import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const paths = vm.createContext({});
vm.runInContext(readFileSync(new URL("../shared/Paths.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\n/, ""), paths);

function model(name) {
  const context = vm.createContext({ Paths: paths });
  vm.runInContext(readFileSync(new URL(
    `../hosts/omarchy/models/${name}.js`, import.meta.url), "utf8")
    .replace(/^\.pragma library\n/, "").replace(/^\.import .*\n/gm, ""), context);
  return context;
}

const facade = model("FacadeModel");
const panel = model("PanelModel");
const source = readFileSync(new URL(
  "../hosts/omarchy/ui/DeviceFoldersForm.qml", import.meta.url), "utf8");

function form(device) {
  const context = vm.createContext({
    device, draftDeviceId: "", originalFolderIds: [], draftFolderIds: [],
    controller: { folderById: id => ({ label: id }) },
  });
  context.root = context;
  for (const method of source.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(method[0], context);
  context.reset();
  return context;
}

function remote(states, { fresh = true, connected = true, paused = false } = {}) {
  const folders = Object.entries(states).map(([id, state]) => ({
    id, label: id, devices: [{ id: "OPTIPLEX", remoteState: state }],
  }));
  return panel.remoteDeviceRows({
    localDeviceId: "XPS", statusFresh: fresh,
    folders: facade.folders(folders),
    devices: facade.devices([{ id: "OPTIPLEX", name: "optiplex", connected, paused }]),
  })[0];
}

function ids(options) {
  return Array.from(options, option => option.value);
}

test("43 established shares and one unknown share remain 44 configured shares", () => {
  const states = Object.fromEntries(Array.from({ length: 43 }, (_, i) => [`folder-${i}`, "valid"]));
  states.useful = "unknown";
  const device = remote(states);
  const edit = form(device);
  assert.equal(device.folderIds.length, 44);
  assert.equal(edit.folderOptions(false).length, 43);
  assert.deepEqual(ids(edit.folderOptions(true)), ["useful"]);
  assert.equal(edit.selectedValues(edit.folderOptions(false)).length, 43);
  assert.deepEqual(Array.from(edit.selectedValues(edit.folderOptions(true))), ["useful"]);
  assert.equal(edit.removedFolderIds().length, 0);
});

test("remote paused is confirmed; notSharing, missing and unknown are unconfirmed", () => {
  const edit = form(remote({ ready: "valid", stopped: "paused", offered: "notSharing",
    useful: "unknown", missing: undefined, unexpected: "future-state" }));
  assert.deepEqual(ids(edit.folderOptions(false)), ["ready", "stopped"]);
  assert.deepEqual(ids(edit.folderOptions(true)), ["offered", "useful", "missing", "unexpected"]);
  assert.match(edit.folderOptions(true)[0].description, /not sharing back/);
  assert.match(edit.folderOptions(true)[1].description, /unconfirmed/);
});

test("stale, disconnected and device-paused snapshots cannot claim confirmation", () => {
  for (const status of [{ fresh: false }, { connected: false }, { paused: true }]) {
    const edit = form(remote({ established: "valid", stopped: "paused" }, status));
    assert.equal(edit.folderOptions(false).length, 0);
    assert.deepEqual(ids(edit.folderOptions(true)), ["established", "stopped"]);
  }
});

test("each dropdown edits only its group without unsharing the other group", () => {
  const edit = form(remote({ established: "valid", useful: "unknown" }));
  edit.setGroupValues(edit.folderOptions(true), []);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["useful"]);
  edit.setGroupValues(edit.folderOptions(false), []);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["established", "useful"]);
  edit.setGroupValues(edit.folderOptions(true), ["useful"]);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["established"]);
});

test("acceptance during editing moves a share without resetting its checkbox", () => {
  const edit = form(remote({ established: "valid", useful: "unknown" }));
  edit.setGroupValues(edit.folderOptions(true), []);
  edit.device = remote({ established: "valid", useful: "valid" });
  edit.reconcileDevice();
  assert.equal(edit.folderOptions(true).length, 0);
  assert.deepEqual(Array.from(edit.selectedValues(edit.folderOptions(false))), ["established"]);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["useful"]);
  edit.device = remote({ established: "valid", useful: "valid" }, { connected: false });
  edit.reconcileDevice();
  assert.deepEqual(Array.from(edit.selectedValues(edit.folderOptions(true))), ["established"]);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["useful"]);
});

test("refresh preserves edits and cannot remove newly added shares", () => {
  const edit = form(remote({ established: "valid", useful: "unknown" }));
  edit.setGroupValues(edit.folderOptions(true), []);
  edit.device = remote({ established: "valid", useful: "unknown", new: "valid" });
  edit.reconcileDevice();
  assert.deepEqual(Array.from(edit.draftFolderIds), ["established", "new"]);
  assert.deepEqual(Array.from(edit.removedFolderIds()), ["useful"]);
  edit.device = remote({ established: "valid", new: "valid" });
  edit.reconcileDevice();
  assert.equal(edit.removedFolderIds().length, 0);
});

test("switching devices resets the draft and closing closes both popups", () => {
  const edit = form(remote({ useful: "unknown" }));
  edit.setGroupValues(edit.folderOptions(true), []);
  edit.device = { id: "CHRONOS", folderIds: ["other"], remoteFolderStates: {} };
  edit.reconcileDevice();
  assert.deepEqual(Array.from(edit.draftFolderIds), ["other"]);
  let closed = 0;
  edit.folderPicker = { close() { closed++; } };
  edit.unconfirmedPicker = { close() { closed++; } };
  edit.closePopups();
  assert.equal(closed, 2);
  assert.match(source, /onDeviceChanged: reconcileDevice\(\)/);
  assert.match(source, /label: "Existing shares"/);
  assert.match(source, /label: "Unconfirmed shares"/);
  assert.equal((source.match(/root\.setGroupValues\(options, values\)/g) || []).length, 2);
});

test("unconfirmed hint is yellow, inline and shortened to the available width", () => {
  const hint = source.match(/id: unconfirmedHint([^]*?)TextMetrics/)[1];
  assert.match(hint, /color: root.warning/);
  assert.match(hint, /wrapMode: Text.NoWrap/);
  assert.match(hint, /fullHint.width <= width/);
  assert.match(hint, /\(acceptance pending, or device offline\)/);
  assert.doesNotMatch(source, /Acceptance is not confirmed; the remote may be offline/);
});
