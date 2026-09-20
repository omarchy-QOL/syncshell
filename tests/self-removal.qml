import QtQuick
import Quickshell
import "../hosts/omarchy"
import "../hosts/omarchy/ui"

ShellRoot {
  id: root
  property int step: 0
  property int themeChanges: 0
  OmarchyService { id: service }
  Item {
    width: 600
    height: 600
    SelfRemovalDialog {
      id: dialog
      anchors.fill: parent
      opened: true
      error: service.settingsError
    }
  }

  function check(value, message) {
    if (!value) {
      console.error(message)
      service.core.terminate()
      Qt.exit(1)
      throw new Error(message)
    }
  }

  function displaysError(item) {
    if (item.visible && item.text === service.settingsError) return true
    for (var i = 0; i < item.children.length; i++) {
      if (displaysError(item.children[i])) return true
    }
    return false
  }

  function blocked(message) {
    service.settings.error = ""
    service.requestSelfRemoval(false)
    check(service.settingsError.indexOf(message) >= 0, "missing explanation: " + message)
    check(!service.settings.removalProcess.running, "blocked removal started a worker")
    check(displaysError(dialog), "removal error is not visible in the dialog")
  }

  function remove(purge, assets) {
    service.requestSelfRemoval(purge)
    check(!service.settingsError, "removal unexpectedly blocked: " + service.settingsError)
    check(service.settings.removalProcess.running, "removal did not start")
    check(service.settings.removalProcess.command[4] === assets, "wrong theme cleanup path")
    check(service.settings.removalProcess.command[5] === (purge ? "purge" : "preserve"),
      "wrong settings cleanup mode")
  }

  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      var settings = service.settings
      var packages = service.packageController
      if (!service.core.protocolReady || !settings._settingsLoaded
          || settings.busy || packages.refreshing) return
      if (root.step === 0) {
        packages.statusTimer.stop()
        settings._settingsValid = false
        settings.reconcileTimer.stop()
        service.core.snapshot = { connection: { online: false },
          webUi: { theme: "syncthing-omarchy", guiAssets: "/stale/gui" } }
        settings.selectTheme = function(theme, success, failure) {
          root.check(theme === "default", "removal must restore the default theme")
          root.themeChanges++
          success()
        }
        packages.packageActionRunning = true
        root.blocked("installation to finish")
        packages.packageActionRunning = false
        packages.operationRunning = true
        root.blocked("installation to finish")
        packages.operationRunning = false
        settings.busy = true
        root.blocked("settings operation")
        settings.busy = false
        packages.state = "existing"
        root.remove(false, "")
        root.check(root.themeChanges === 0, "stopped Syncthing changed the theme")
      } else if (root.step === 1) {
        packages.state = "missing"
        root.remove(true, "")
        root.check(root.themeChanges === 0, "missing installation changed the theme")
      } else if (root.step === 2) {
        // A reachable daemon takes precedence over a missing local executable.
        service.core.snapshot = { connection: { online: true },
          webUi: { theme: "syncthing-omarchy", guiAssets: "/test/gui" } }
        root.remove(false, "/test/gui")
        root.check(root.themeChanges === 1, "owned theme was not restored")
      } else if (root.step === 3) {
        service.core.snapshot = { connection: { online: true },
          webUi: { theme: "owner-theme", guiAssets: "/test/gui" } }
        root.remove(true, "/test/gui")
        root.check(root.themeChanges === 1, "unrelated theme was changed")
      } else {
        service.core.snapshot = { connection: { online: true },
          webUi: { theme: "syncthing-omarchy", guiAssets: "" } }
        root.blocked("GUI assets path")
        service.core.snapshot = { connection: { online: true },
          webUi: { theme: "syncthing-omarchy", guiAssets: "/test/gui" } }
        settings.selectTheme = function(theme, success, failure) {
          failure({ message: "theme reset failed" })
        }
        root.blocked("theme reset failed")
        service.core.terminate()
        console.log("self removal controller tests passed")
        Qt.quit()
      }
      root.step++
    }
  }

  Timer {
    interval: 10000
    running: true
    onTriggered: root.check(false, "self removal timed out at step " + root.step)
  }
}
