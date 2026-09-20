import QtQuick

QtObject {
  id: root

  readonly property var runningFolderIds: _runningFolderIds
  property var _runningFolderIds: []

  signal completed

  function validIds(values) {
    if (!Array.isArray(values)) return false
    var previous = ""
    for (var index = 0; index < values.length; index++) {
      if (typeof values[index] !== "string" || values[index] === ""
          || index > 0 && values[index] <= previous) return false
      previous = values[index]
    }
    return true
  }

  function acceptResult(data, scanningFolderIds) {
    if (!data || typeof data !== "object"
        || data.state !== "completed" && data.state !== "running"
        || !validIds(data.targetFolderIds)
        || !validIds(data.runningFolderIds)) return false
    var targets = ({})
    for (var index = 0; index < data.targetFolderIds.length; index++)
      targets[data.targetFolderIds[index]] = true
    for (var runningIndex = 0;
        runningIndex < data.runningFolderIds.length; runningIndex++) {
      if (!targets[data.runningFolderIds[runningIndex]]) return false
    }
    if (data.state === "completed") {
      if (data.runningFolderIds.length !== 0) return false
      reset()
      completed()
      return true
    }
    if (data.runningFolderIds.length === 0) return false
    _runningFolderIds = data.runningFolderIds.slice()
    reconcile(scanningFolderIds)
    return true
  }

  function reconcile(scanningFolderIds) {
    if (_runningFolderIds.length === 0) return
    var scanning = ({})
    var values = Array.isArray(scanningFolderIds) ? scanningFolderIds : []
    for (var index = 0; index < values.length; index++)
      scanning[String(values[index])] = true
    for (var runningIndex = 0;
        runningIndex < _runningFolderIds.length; runningIndex++) {
      if (scanning[_runningFolderIds[runningIndex]]) return
    }
    reset()
    completed()
  }

  function reset() {
    _runningFolderIds = []
  }
}
