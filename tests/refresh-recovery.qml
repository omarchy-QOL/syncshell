import QtQuick
import Quickshell
import "../hosts/omarchy"

ShellRoot {
  id: root
  property int step: 0

  OmarchyService { id: service }

  function check(value, message) {
    if (!value) {
      console.error(message)
      service.core.terminate()
      Qt.exit(1)
    }
  }

  Timer {
    interval: 25
    repeat: true
    running: true
    onTriggered: {
      if (!service.canRefresh) return
      if (root.step === 0) {
        if (!service.online || !service.settingsReady) return
        root.step = 1
        service.refresh()
      } else if (root.step === 1) {
        if (service.online) return
        root.check(service.lastError === "API unavailable",
          "failed refresh is visible through connection state")
        root.check(!service.statusFresh, "failed refresh is not fresh")
        root.step = 2
        service.refresh()
      } else if (root.step === 2) {
        if (!service.online) return
        root.check(service.lastError === "" && service.controlError === "",
          "successful refresh must clear the prior refresh error")
        root.check(service.statusFresh, "recovered state is fresh")
        service.controlError = "service start failed"
        root.step = 3
        service.refresh()
      } else {
        root.check(service.controlError === "service start failed",
          "refresh must not erase an unrelated lifecycle error")
        service.core.terminate()
        console.log("refresh recovery tests passed")
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 8000
    running: true
    onTriggered: {
      console.error("refresh recovery test timed out")
      service.core.terminate()
      Qt.exit(1)
    }
  }
}
