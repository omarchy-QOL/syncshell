import QtQuick
import Quickshell
import Quickshell.Io
import "../hosts/omarchy/controllers"

ShellRoot {
  id: root

  property int stage: 0
  property int starts: 0
  property int finishes: 0
  property int debounceStarts: 0
  property int queueFinishes: 0

  function check(value, message) {
    if (value) return
    console.error(message)
    Qt.exit(1)
  }

  function checkPalette(warning, success, activity, message) {
    check(String(palette.warning) === warning
      && String(palette.success) === success
      && String(palette.syncActivity) === activity, message)
  }

  function setMode(value) {
    modeFile.setText(value + "\n")
  }

  FileView {
    id: modeFile
    path: Quickshell.env("TEST_PALETTE_MODE")
  }

  ThemePaletteController {
    id: palette
    resolverCommand: [Quickshell.env("TEST_PALETTE_HELPER")]

    onRefreshStarted: {
      root.starts++
      if (root.stage === 5 && root.starts === root.debounceStarts + 1) {
        refreshNow()
        refreshNow()
        refreshNow()
      }
    }

    onRefreshFinished: function(applied) {
      root.finishes++
      if (root.stage === 0) {
        root.check(applied, "valid startup palette was rejected")
        root.checkPalette("#112233", "#445566", "#778899",
          "startup palette was not applied")
        root.stage = 1
        root.setMode("failure")
        Qt.callLater(refreshNow)
      } else if (root.stage === 1) {
        root.check(!applied, "failed resolver was applied")
        root.checkPalette("#112233", "#445566", "#778899",
          "failed resolver replaced the last valid palette")
        root.stage = 2
        root.setMode("malformed")
        Qt.callLater(refreshNow)
      } else if (root.stage === 2) {
        root.check(!applied, "malformed palette was applied")
        root.checkPalette("#112233", "#445566", "#778899",
          "malformed output replaced the last valid palette")
        root.stage = 3
        root.setMode("success")
        root.debounceStarts = root.starts
        scheduleRefresh()
        scheduleRefresh()
        scheduleRefresh()
      } else if (root.stage === 3) {
        root.check(applied && root.starts === root.debounceStarts + 1,
          "theme notifications were not debounced")
        root.checkPalette("#aabbcc", "#ddeeff", "#123456",
          "refreshed palette was not applied")
        root.stage = 4
        settleTimer.restart()
      } else if (root.stage === 5) {
        root.queueFinishes++
        if (root.queueFinishes < 2) return
        root.check(root.starts === root.debounceStarts + 2,
          "concurrent requests did not queue exactly one refresh")
        root.checkPalette("#aabbcc", "#ddeeff", "#123456",
          "queued refresh lost the valid palette")
        console.log("theme palette controller tests passed")
        Qt.quit()
      }
    }
  }

  Timer {
    id: settleTimer
    interval: 300
    onTriggered: {
      root.check(root.starts === root.debounceStarts + 1,
        "debounced refresh started more than once")
      root.stage = 5
      root.queueFinishes = 0
      root.debounceStarts = root.starts
      root.setMode("slow")
      palette.refreshNow()
    }
  }

  Component.onCompleted: {
    setMode("startup")
    palette.refreshNow()
  }

  Timer {
    interval: 5000
    running: true
    onTriggered: {
      console.error("theme palette test timed out at stage " + root.stage)
      Qt.exit(1)
    }
  }
}
