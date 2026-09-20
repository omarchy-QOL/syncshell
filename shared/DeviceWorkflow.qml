import QtQuick

QtObject {
  id: root

  required property var service
  property string view: ""
  property string targetDeviceId: ""
  property string targetDeviceName: ""
  property string targetFolderId: ""
  property var draftIds: []
  property string pendingFolderId: ""
  property string pendingFolderDeviceId: ""

  function shortId(value) {
    return String(value || "").split("-")[0]
  }

  function toggleDraft(value) {
    var next = draftIds.slice()
    var index = next.indexOf(value)
    if (index < 0) next.push(value)
    else next.splice(index, 1)
    draftIds = next
  }

  function beginAddDevice(device) {
    var value = device || ({})
    targetDeviceId = String(value.id || "")
    targetDeviceName = String(value.name || "")
    view = "add-device"
  }

  function beginFolderSharing(folder) {
    targetFolderId = String(folder.id || "")
    draftIds = service.remoteDeviceIdsForFolder(targetFolderId)
    view = "share-folder"
  }

  function beginDeviceFolders(device) {
    targetDeviceId = String(device.id || "")
    targetDeviceName = String(device.name || "")
    draftIds = service.folderIdsForDevice(targetDeviceId)
    view = "device-folders"
  }

  function beginDismissDevice(device) {
    targetDeviceId = String(device.id || "")
    targetDeviceName = String(device.name || "")
    view = "dismiss-device"
  }

  function removedFolderIds() {
    var original = service.folderIdsForDevice(targetDeviceId)
    var removed = []
    for (var index = 0; index < original.length; index++) {
      if (draftIds.indexOf(original[index]) < 0) removed.push(original[index])
    }
    return removed
  }

  function selectPendingFolder(offer) {
    var value = offer || ({})
    pendingFolderId = String(value.folderId || "")
    pendingFolderDeviceId = String(value.deviceId || "")
    return pendingFolderId
  }

  function pendingDeviceId(folderId) {
    return String(folderId || "") === pendingFolderId
      ? pendingFolderDeviceId : ""
  }

  function resetFolderDraft() {
    pendingFolderId = ""
    pendingFolderDeviceId = ""
    draftIds = []
  }

  function close() {
    view = ""
    targetDeviceId = ""
    targetDeviceName = ""
    targetFolderId = ""
    draftIds = []
  }

  function actionFinished(action, ok) {
    if (ok && (action === "folder.set-sharing"
        || String(action || "").indexOf("device.") === 0)) close()
  }
}
