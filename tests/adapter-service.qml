import QtQuick
import Quickshell
import "../shared"

ShellRoot {
  id: root

  property int stage: 0

  function fail(message) {
    console.error(message)
    service.core.terminate()
    Qt.exit(1)
  }

  AdapterService {
    id: service
    pluginRoot: Quickshell.env("SYNCSHELL_TEST_PLUGIN_ROOT")
    hostId: "adapter-test"

    onOnlineChanged: if (online && root.stage === 0) {
      root.stage = 1
      if (!rescanFolder("docs") || !busy)
        root.fail("rescan did not become busy immediately")
      if (rescanFolder("docs")) root.fail("duplicate rescan was accepted")
    }

    onActionFinished: function(action, ok, data, error) {
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
        service.core.terminate()
        finishTimer.restart()
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
