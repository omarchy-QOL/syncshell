import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "hosts/omarchy"

ShellRoot {
  id: root
  property bool announced: false
  property bool scanning: false
  readonly property bool missing: Quickshell.env("SYNCSHELL_WITHOUT_WEBUI") === "1"

  function fail(message) {
    console.error("PLUGIN_FAILED: " + message)
    service.core.terminate()
    Qt.exit(1)
  }

  OmarchyService { id: service }
  IpcHandler {
    target: "shell"
    // Use the installed shell's palette entry point rather than file watching.
    function applyTheme(colorsB64: string, shellB64: string): string {
      Color.loadColors(Qt.atob(colorsB64))
      Color.loadShell(Qt.atob(shellB64))
      Style.scheduleRefresh()
      return "ok"
    }
  }
  FileView {
    id: control
    path: Quickshell.env("SYNCSHELL_TEST_CONTROL")
    watchChanges: true
    onFileChanged: reload()
  }
  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: {
      if (!root.announced && service.online && service.settings.settingsReady
          && !service.settings.busy) {
        if (root.missing && service.settings.error === "") return
        if (!root.missing && (service.settings.error !== ""
            || service.webUi.theme !== "syncthing-omarchy")) return
        root.announced = true
        console.log("PLUGIN_READY")
      }
      if (!root.announced) return
      if (!root.scanning && control.text().trim() === "rescan") {
        root.scanning = true
        if (!service.rescanFolder("launcher-test")) root.fail("rescan refused")
        return
      }
      if (root.scanning && !service.folderMutationBusy) {
        if (service.folderMutationError !== "") {
          root.fail(service.folderMutationError)
          return
        }
        console.log("PLUGIN_SCAN_OK")
        service.core.terminate()
        Qt.exit(0)
      }
    }
  }
  Timer {
    interval: 60000
    running: true
    onTriggered: root.fail("acceptance timed out: " + service.settings.error)
  }
}
