import QtQuick
import Quickshell
import "../hosts/omarchy"

ShellRoot {
  id: root

  property bool armed: false
  property bool apiLossChecked: false

  function fail(message) {
    console.error(message)
    service.core.terminate()
    Qt.exit(1)
  }

  OmarchyService {
    id: service
  }

  Timer {
    interval: 25
    repeat: true
    running: true
    onTriggered: {
      if (!root.armed && service.core.running && service.core.protocolReady) {
        if (!root.apiLossChecked) {
          service.core.snapshot = {
            connection: { online: true },
            folders: [{ id: "folder", status: { state: "scanning" } }]
          }
          service.folderMutationBusy = true
          service.folderMutationAction = "rescan"
          service.folderMutationId = "folder"
          service.pendingRescanResultReady = true
          service.core.snapshot = Object.assign({}, service.core.snapshot, {
            connection: { online: false }
          })
          if (service.folderMutationBusy || service.pendingRescanResultReady
              || service.folderMutationError === ""
              || service.folderMutationNotice !== "") {
            root.fail("API loss retained an accepted rescan or reported success")
            return
          }
          root.apiLossChecked = true
        }
        root.armed = true
        service.folderMutationBusy = true
        service.folderMutationAction = "rescan"
        service.folderMutationId = "folder"
        service.core.coreProcess.signal(9)
        return
      }
      if (!root.armed || service.folderMutationBusy) return
      if (service.online || service.canControlService) {
        root.fail("core loss retained available actions")
        return
      }
      if (service.folderMutationAction !== ""
          || service.folderMutationId !== "") {
        root.fail("core loss retained optimistic rescan state")
        return
      }
      if (service.folderMutationError
          !== "Folder operation stopped because native core became unavailable") {
        root.fail("core loss did not report its terminal state")
        return
      }
      service.core.terminate()
      console.log("rescan core-loss test passed")
      Qt.exit(0)
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: false
    onTriggered: root.fail("rescan core-loss test timed out")
  }
}
