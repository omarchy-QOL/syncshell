import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const service = readFileSync(new URL(
  "../hosts/omarchy/OmarchyService.qml", import.meta.url), "utf8");
const panel = readFileSync(new URL(
  "../hosts/omarchy/OmarchyPanel.qml", import.meta.url), "utf8");

function method(source, name, indent = "  ") {
  const pattern = new RegExp(
    "^" + indent + "function " + name + "\\([^]*?^" + indent + "}", "m");
  const match = source.match(pattern);
  assert.ok(match, name);
  return match[0];
}

let callback;
let request;
let prompt;
let failure;
const context = vm.createContext({
  online: true,
  folderMutationBusy: false,
  noticeTimer: { stop() {} },
  rescanTracker: { reset() {} },
  core: { action(action, args, reply) {
    request = { action, args };
    callback = reply;
    return "request-id";
  } },
  clearFolderAction() { context.folderMutationBusy = false; },
  folderDirectoryRequired(args) { prompt = args; },
  failFolderAction(error) { failure = error; },
});
context.root = context;
vm.runInContext(method(service, "runFolderAction")
  + "\n" + method(service, "addFolder"), context);

const devices = ["chronos"];
assert.equal(context.addFolder("/tmp/missing", "Shared", "offer", devices,
  "chronos"), true);
devices.push("another-device");
assert.equal(request.args.createDirectory, false);
assert.deepEqual(Array.from(request.args.deviceIds), ["chronos"]);
callback(false, null, { code: "path_missing" });
assert.equal(context.folderMutationBusy, false);
assert.equal(prompt.path, "/tmp/missing");
assert.equal(failure, undefined);

prompt = null;
context.addFolder("/tmp/blocked", "Shared", "offer", [], "");
callback(false, null, { code: "path_unavailable" });
assert.equal(prompt, null);
assert.equal(failure.code, "path_unavailable");

context.folderMutationBusy = false;
context.addFolder("/tmp/missing", "Shared", "offer", [], "", true);
assert.equal(request.args.createDirectory, true);
callback(false, null, { code: "path_missing" });
assert.equal(prompt, null);
assert.equal(failure.code, "path_missing");

let submitted;
const controller = vm.createContext({
  opened: true,
  addOpen: true,
  popup: { closeTransientPopups() {}, focusPanel() {} },
  syncthing: { addFolder(...args) { submitted = args; return true; } },
});
controller.root = controller;
vm.runInContext(method(panel, "onFolderDirectoryRequired", "    ") + "\n"
  + method(panel, "cancelFolderAction") + "\n"
  + method(panel, "confirmFolderAction"), controller);
const original = {
  path: "/tmp/original", label: "Original", folderId: "offer",
  deviceIds: ["chronos"], pendingDeviceId: "chronos",
};
controller.onFolderDirectoryRequired(original);
assert.equal(controller.folderConfirmAction, "create");
controller.cancelFolderAction();
assert.equal(submitted, undefined);
assert.equal(controller.folderCreationArgs, null);

controller.onFolderDirectoryRequired(original);
controller.popup.addPathText = "/tmp/edited";
controller.confirmFolderAction();
assert.deepEqual(Array.from(submitted), [
  "/tmp/original", "Original", "offer", ["chronos"], "chronos", true,
]);
assert.equal(controller.folderCreationArgs, null);
assert.equal(controller.addSubmissionPending, true);
controller.opened = false;
controller.onFolderDirectoryRequired(original);
assert.equal(controller.folderCreationArgs, null);
console.log("folder creation confirmation tests passed");
