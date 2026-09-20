import QtQuick
import Quickshell.Io
import "../models/ThemePaletteModel.js" as ThemePaletteModel

QtObject {
  id: root

  property var resolverCommand: ["omarchy-theme-color", "--all"]
  property var _palette: ThemePaletteModel.defaults()
  property string _output: ""
  property bool _refreshAgain: false

  readonly property color warning: _palette.yellow
  readonly property color success: _palette.green
  readonly property color syncActivity: _palette.cyan
  readonly property bool refreshing: resolver.running

  signal refreshStarted
  signal refreshFinished(bool applied)

  function scheduleRefresh() {
    refreshTimer.restart()
  }

  function refreshNow() {
    refreshTimer.stop()
    if (resolver.running) {
      _refreshAgain = true
      return
    }
    _output = ""
    resolver.running = true
  }

  property Timer refreshTimer: Timer {
    interval: 150
    repeat: false
    onTriggered: root.refreshNow()
  }

  property Process resolver: Process {
    command: root.resolverCommand

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._output = text
    }

    onStarted: root.refreshStarted()
    onExited: function(exitCode) {
      var next = exitCode === 0 ? ThemePaletteModel.parse(root._output) : null
      var rerun = root._refreshAgain
      root._refreshAgain = false
      if (next) root._palette = next
      root.refreshFinished(!!next)
      if (rerun) Qt.callLater(root.refreshNow)
    }
  }
}
