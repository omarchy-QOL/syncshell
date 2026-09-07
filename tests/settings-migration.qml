import QtQuick
import Quickshell
import Quickshell.Io
import "../hosts/omarchy"

ShellRoot {
  id: root
  property int step: 0
  property int ticks: 0
  property string older: ""
  OmarchyService { id: service }
  FileView { id: source; path: service.settings.settingsPath }
  FileView {
    id: reference
    path: Quickshell.env("TEST_REFERENCE")
    printErrors: false
  }

  function check(value, message) {
    if (!value) {
      console.error(message)
      service.core.terminate()
      Qt.exit(1)
    }
  }

  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      root.ticks++
      var settings = service.settings
      if (!service.online || !settings._settingsLoaded || settings.busy) return
      if (root.step === 0) {
        if (root.ticks < 10) return
        root.check(!service.settingsReady && service.settingsMigrationOpen
          && service.settingsCanAutoPort, "old startup must require migration")
        root.check(service.settingsMigrationMessage.indexOf(source.path) >= 0,
          "migration identifies the actual file")
        root.check(!settings.themeProcess.running, "no startup theme preparation")
        root.older = source.text()
        service.cancelSettingsMigration()
        service.recheckSettings()
        root.step = 1
      } else if (root.step === 1) {
        root.check(!service.settingsMigrationOpen && !service.settingsReady,
          "cancel must not reopen on reload")
        root.check(service.settingsError.indexOf("status monitoring") >= 0,
          "cold cancel warning is actionable")
        service.openSettings()
        root.check(service.settingsMigrationOpen, "settings explicitly reopens")
        service.manualPortSettings()
        root.step = 2
      } else if (root.step === 2) {
        if (!service.settingsNotice) return
        root.check(!service.settingsMigrationOpen && !service.settingsReady,
          "manual comparison must not apply the template")
        reference.setText('version = 999\n')
        service.recheckSettings()
        root.step = 3
      } else if (root.step === 3) {
        root.check(!service.settingsReady && settings._settingsRaw === root.older,
          "reference edits do not change active settings")
        service.openSettings()
        service.autoPortSettings()
        root.step = 4
      } else if (root.step === 4) {
        if (!service.settingsReady) return
        root.check(!service.settingsMigrationOpen, "auto-port closes after apply")
        root.check(service.settingsNotice.indexOf(".before-port.") >= 0,
          "successful writer output includes the backup path")
        root.check(service.configuredServiceState === "disabled"
          && service.probeIntervalSeconds === 27 && service.iconStyle === "themed",
          "auto-port preserves effective preferences")
        source.setText(settings._settingsRaw.replace('web_ui_theme = "default"',
          'web_ui_theme = "dfault"'))
        root.step = 5
      } else if (root.step === 5) {
        if (service.settingsReady) return
        root.check(!service.settingsMigrationOpen && service.settingsError,
          "current schema typo is a validation error")
        root.check(service.configuredServiceState === "disabled"
          && service.probeIntervalSeconds === 27, "last good values retained")
        settings.finishReconcile("")
        root.check(!!service.settingsError, "late completion preserves validation error")
        source.setText(root.older.replace('version = 1', 'version = 2'))
        root.step = 6
      } else {
        if (!service.settingsReady) return
        root.check(!service.settingsError, "corrected save recovers automatically")
        service.core.terminate()
        console.log("settings migration controller tests passed")
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    onTriggered: {
      console.error("settings migration timed out at step " + root.step)
      service.core.terminate()
      Qt.exit(1)
    }
  }
}
