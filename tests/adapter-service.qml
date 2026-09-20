import QtQuick
import Quickshell
import "../shared"

ShellRoot {
  id: root

  property int stage: 0
  property DeviceWorkflow workflow: DeviceWorkflow { service: service }

  function fail(message) {
    console.error(message)
    service.core.terminate()
    Qt.exit(1)
  }

  function begin() {
    if (stage !== 0 || !service.online) return
    stage = 1
    if (service.localDeviceId !== "LOCAL"
        || service.remoteDevices().length !== 1
        || service.folderIdsForDevice("REMOTE").join(",") !== "docs"
        || service.pendingDevices.length !== 1
        || service.nearbyDevices.length !== 1
        || service.pendingFolderOffers().length !== 1)
      fail("device state was not projected")
    workflow.beginAddDevice({ id: "NEARBY", name: "Nearby" })
    if (workflow.view !== "add-device"
        || workflow.targetDeviceId !== "NEARBY"
        || workflow.targetDeviceName !== "Nearby")
      fail("device add workflow was not initialized")
    workflow.beginFolderSharing({ id: "docs" })
    if (workflow.draftIds.join(",") !== "REMOTE")
      fail("folder sharing workflow did not project members")
    workflow.toggleDraft("REMOTE")
    if (workflow.draftIds.length !== 0)
      fail("folder sharing workflow did not update the draft")
    workflow.beginDeviceFolders({ id: "REMOTE", name: "Remote" })
    workflow.toggleDraft("docs")
    if (workflow.removedFolderIds().join(",") !== "docs")
      fail("device workflow did not compute explicit removals")
    if (workflow.selectPendingFolder({ folderId: "offered",
        deviceId: "PENDING" }) !== "offered"
        || workflow.pendingDeviceId("offered") !== "PENDING"
        || workflow.pendingDeviceId("other") !== "")
      fail("pending folder workflow was not resolved")
    workflow.actionFinished("device.add", true)
    if (workflow.view !== "" || workflow.targetDeviceId !== "")
      fail("successful device workflow did not close")
    if (!service.rescanFolder("docs") || !service.busy)
      fail("rescan did not become busy immediately")
    if (service.rescanFolder("docs")) fail("duplicate rescan was accepted")
  }

  AdapterService {
    id: service
    pluginRoot: Quickshell.env("SYNCSHELL_TEST_PLUGIN_ROOT")

    onOnlineChanged: if (online && root.stage === 0)
      Qt.callLater(root.begin)

    onActionFinished: function(action, ok, data, error) {
      if (root.stage === 7) {
        if (ok || action !== "folder.rescan" || busy
            || rescanTracker.runningFolderIds.length !== 0
            || actionNotice !== "" || actionError === "") {
          root.fail("shared adapter retained a rescan after API loss")
          return
        }
        root.stage = 8
        service.core.terminate()
        finishTimer.restart()
        return
      }
      if (!ok || error) {
        root.fail("adapter action failed: " + JSON.stringify(error))
        return
      }
      if (root.stage === 1) {
        if (action !== "folder.rescan" || busy
            || actionNotice !== "Rescan complete for Documents") {
          root.fail("rescan did not settle after scanning")
          return
        }
        root.stage = 2
        requestFolderIdSuggestion()
      } else if (root.stage === 2) {
        if (folderIdSuggestion !== "abcde-fghij") {
          root.fail("folder ID suggestion was not projected")
          return
        }
        root.stage = 3
        setFolderSharing("docs", ["REMOTE"])
      } else if (root.stage === 3) {
        if (action !== "folder.set-sharing") {
          root.fail("folder sharing action was not forwarded")
          return
        }
        root.stage = 4
        addDevice("NEARBY", "Laptop")
      } else if (root.stage === 4) {
        if (action !== "device.add") {
          root.fail("device add action was not forwarded")
          return
        }
        root.stage = 5
        dismissPendingDevice("PENDING", "Laptop")
      } else if (root.stage === 5) {
        if (action !== "device.dismiss-pending") {
          root.fail("pending device action was not forwarded")
          return
        }
        root.stage = 6
        removeDeviceFolderShares("REMOTE", ["docs"], "Remote")
      } else if (root.stage === 6) {
        if (action !== "device.remove-folder-shares") {
          root.fail("device share action was not forwarded")
          return
        }
        root.stage = 7
        service.core.snapshot = Object.assign({}, service.core.snapshot, {
          connection: { online: true },
          folders: [{
            id: "docs",
            label: "Documents",
            paused: false,
            status: { state: "scanning" }
          }]
        })
        service._actionRequest = "accepted-rescan"
        service._actionName = "folder.rescan"
        service._actionTargetId = "docs"
        service.actionNotice = ""
        service.actionError = ""
        if (!service.rescanTracker.acceptResult({
            state: "running",
            targetFolderIds: ["docs"],
            runningFolderIds: ["docs"]
          }, ["docs"])) {
          root.fail("shared adapter rejected a valid running rescan")
          return
        }
        service.core.snapshot = Object.assign({}, service.core.snapshot, {
          connection: { online: false }
        })
      }
    }
  }

  Timer {
    id: finishTimer
    interval: 50
    onTriggered: {
      if (service.core.running) {
        restart()
        return
      }
      console.log("adapter service tests passed")
      Qt.exit(0)
    }
  }

  Timer {
    interval: 10000
    running: true
    onTriggered: root.fail("adapter service test timed out")
  }
}
