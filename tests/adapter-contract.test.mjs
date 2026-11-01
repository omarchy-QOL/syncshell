import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../shared/AdapterService.qml",
  import.meta.url), "utf8");

function service(overrides = {}) {
  const context = vm.createContext({
    probeIntervalSeconds: 15, refreshIntervalSeconds: 60,
    desiredServiceState: "disabled", lifecyclePolicy: {},
    lifecycleAuthorized: false, desktopAuthorized: false,
    profilePolicy: {},
    configPath: "", endpoint: "", credentialFile: "", tlsCertificate: "",
    expectedDeviceId: "", canControlService: false, canStartService: false,
    online: true, busy: false, refreshing: false, baseUrl: "http://127.0.0.1:8384",
    homePath: "/home/test", actionError: "", actionNotice: "",
    folders: [], devices: [], pendingFolders: {}, localDeviceId: "",
    Paths: { resolveFolderPath: path => path },
    core: { protocolReady: true },
    rescanTracker: { reset() {} },
    Qt: { openUrlExternally() { throw Error("unexpected external open"); } },
    ...overrides,
  });
  context.root = context;
  for (const match of source.matchAll(/^    function \w+\([^]*?^    }/gm))
    vm.runInContext(match[0], context);
  return context;
}

test("omitted host policy grants no lifecycle or desktop authority", () => {
  const host = service();
  const args = Array.from(host.startupArguments());
  assert.deepEqual(args, ["--probe-interval-seconds", "15",
    "--desired-service-state", "disabled"]);
  assert.match(source, /property var lifecyclePolicy: \(\{\}\)/);
  assert.match(source, /property bool desktopAuthorized: false/);
  assert.equal(host.setServiceEnabled(true), false);
  assert.match(host.actionError, /externally managed/);
});

test("host passes the exact authorized binding and private target paths", () => {
  const host = service({
    lifecycleAuthorized: true,
    lifecyclePolicy: { kind: "systemd-user", unit: "syncthing-test.service",
      configPath: "/private/config.xml" },
    desktopAuthorized: true, configPath: "/private/config.xml",
    endpoint: "https://localhost:8384", credentialFile: "/private/key",
    tlsCertificate: "/private/cert", expectedDeviceId: "TARGET",
  });
  assert.deepEqual(Array.from(host.startupArguments()), [
    "--probe-interval-seconds", "15", "--desired-service-state", "disabled",
    "--lifecycle-kind", "systemd-user", "--lifecycle-authorized",
    "--lifecycle-unit", "syncthing-test.service",
    "--lifecycle-config", "/private/config.xml", "--desktop-authorized",
    "--config", "/private/config.xml", "--endpoint", "https://localhost:8384",
    "--credential-file", "/private/key", "--tls-certificate", "/private/cert",
    "--expected-device-id", "TARGET",
  ]);
});

test("only verified lifecycle authority permits starting an offline instance", () => {
  let sent;
  const host = service({ online: false, canStartService: true,
    canControlService: true, core: { protocolReady: true,
      action(name, args) { sent = name; return "1"; } },
  });
  assert.equal(host.setServiceEnabled(true), true);
  assert.equal(sent, "lifecycle.enable");
  assert.equal(host.rescanAllFolders(), false);
  host.canStartService = false;
  assert.equal(host.setServiceEnabled(true), false);
});

test("confirmed directory creation and invitation target survive dispatch", () => {
  let sent;
  const host = service();
  host.runAction = (name, args) => { sent = { name, args }; return true; };
  const deviceIds = ["REMOTE"];
  host.addFolder({ path: "/tmp/missing", folderId: "docs", deviceIds,
    pendingDeviceId: "REMOTE" });
  assert.equal(sent.args.createDirectory, false);
  host.addFolder({ path: "/tmp/missing", folderId: "docs", deviceIds,
    pendingDeviceId: "REMOTE", createDirectory: true });
  deviceIds.push("OTHER");
  assert.equal(sent.args.createDirectory, true);
  assert.deepEqual(Array.from(sent.args.deviceIds), ["REMOTE"]);
  assert.equal(sent.args.pendingDeviceId, "REMOTE");
  host.dismissPendingFolder("offer", "SENDER");
  assert.equal(sent.name, "folder.dismiss-pending");
  assert.equal(sent.args.folderId, "offer");
  assert.equal(sent.args.pendingDeviceId, "SENDER");
  host.recheckErrors();
  assert.equal(sent.name, "folder.recheck-errors");
});

test("authorized Web UI uses the core desktop bridge", () => {
  let action;
  const host = service({ desktopAuthorized: true });
  host.runAction = name => { action = name; return true; };
  assert.equal(host.openWebUi(), true);
  assert.equal(action, "webui.open");
});

test("manual refresh retries a stopped worker after installation or startup failure", () => {
  let restarted = 0;
  const host = service({ core: { protocolReady: false,
    restart() { restarted++; return true; } } });
  assert.equal(host.refresh(), true);
  assert.equal(restarted, 1);
  host.busy = true;
  assert.equal(host.refresh(), false);
  assert.equal(restarted, 1);
});

test("action success, failure and duplicate submissions settle once", () => {
  let reply;
  const finished = [];
  const host = service({
    core: { protocolReady: true,
      action(name, args, callback) { reply = callback; return "1"; } },
    actionFinished: (...args) => finished.push(args),
  });
  Object.defineProperty(host, "busy", { get: () => !!host._actionRequest });
  assert.equal(host.recheckErrors(), true);
  assert.equal(host.busy, true);
  assert.equal(host.recheckErrors(), false);
  reply(false, null, { code: "offline", message: "Lost connection" });
  assert.equal(host.busy, false);
  assert.equal(host.actionError, "Lost connection");
  assert.equal(finished.length, 1);
  host.recheckErrors();
  reply(true, {}, null);
  assert.equal(host.busy, false);
  assert.equal(host.actionNotice, "Folder errors checked");
  assert.equal(finished.length, 2);
});

test("action notices use Omarchy's wording", () => {
  const host = service({
    localDeviceId: "LOCAL",
    folders: [{ id: "docs", label: "Docs", devices: [{ id: "LOCAL" }] },
      { id: "work", label: "Work", devices: [{ id: "LOCAL" }, { id: "PEER" }] }],
    devices: [{ id: "PEER", name: "laptop" }],
    pendingFolders: { offer: { offeredBy: { PEER: { label: "Photos" } } } },
    core: { protocolReady: true,
      action(name, args, callback) { callback(true, {}, null); return "1"; } },
    actionFinished() {},
  });
  const notice = run => (run(), host.actionNotice);
  assert.equal(notice(() => host.setFolderPaused("docs", true)),
    "Synchronization for Docs paused. The folder ID, device associations, and data remain.");
  assert.equal(notice(() => host.setFolderPaused("docs", false)),
    "Linked Docs. Syncthing resumed the folder with its existing sharing configuration.");
  assert.match(notice(() => host.forgetFolder("docs")), /^Removed from Syncthing configuration.*Re-add Folder ID docs/);
  assert.equal(notice(() => host.addFolder({ folderId: "new", label: "New", path: "/n" })),
    "Added New locally. It is linked but not shared with another device.");
  assert.equal(notice(() => host.addFolder({ folderId: "new", path: "/n", deviceIds: ["PEER"] })),
    "Remote devices may have to accept the folder.");
  assert.equal(notice(() => host.setFolderSharing("docs", ["PEER"])),
    "Docs shared with laptop; waiting for laptop to accept.");
  assert.equal(notice(() => host.setFolderSharing("work", ["PEER"])), "Sharing with laptop updated.");
  assert.equal(notice(() => host.setFolderSharing("work", [])),
    "Folder sharing removed. The local folder remains configured.");
  assert.equal(notice(() => host.dismissPendingFolder("offer", "PEER")), "Rejected folder request for Photos.");
  assert.equal(notice(() => host.addDevice("PEER", "laptop")),
    "laptop added. Add this device on laptop to complete connection.");
  assert.equal(notice(() => host.removeDevice("PEER", "laptop")), "laptop removed from this device.");
});
