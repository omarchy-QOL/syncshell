import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
  id: root

  property var controller
  property var syncthing
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color urgent: Color.urgent
  required property color warning
  required property color success
  property string fontFamily: Style.font.family
  property alias addPathText: addForm.pathText
  property alias addLabelText: addForm.labelText
  property alias addIdText: addForm.idText
  property alias selectedDeviceIds: addForm.selectedDeviceIds
  property alias pendingFolderValue: addForm.pendingFolderValue
  readonly property var currentFolder: root.controller.currentFolderRow
  readonly property int shownErrorCount: currentFolder
    ? (currentFolder.errorDetails || []).length : 0
  readonly property int totalErrorCount: currentFolder
    ? Math.max(shownErrorCount, Number(currentFolder.errorCount || 0)) : 0
  readonly property bool folderPopupOpen: folderSelector.popupOpen
  readonly property bool pendingPopupOpen: pendingOfferSelector.popupOpen
  readonly property bool childPopupOpen: folderSharingForm.popupOpen
    || remoteDevices.popupOpen

  function closePopups() {
    if (folderSelector.popupOpen) folderSelector.close()
    if (pendingOfferSelector.popupOpen) pendingOfferSelector.close()
    addForm.closePopups()
    folderSharingForm.closePopups()
    remoteDevices.closePopups()
  }

  function installationStatusText() {
    if (!syncthing) return "Unavailable"
    if (syncthing.installationState === "existing") {
      return "Existing installation found: <font color=\""
        + success + "\">working</font>"
    }
    if (syncthing.installationState === "incomplete") {
      return "Incomplete installation: <font color=\""
        + urgent + "\">non-working</font>"
    }
    return syncthing.installationLabel || "Unavailable"
  }

  function installationStatusColor() {
    if (!syncthing) return dim
    if (syncthing.installationState === "existing") return success
    if (syncthing.installationState === "incomplete") return urgent
    if (syncthing.installationState === "missing") return warning
    return dim
  }

  function resetAddForm() {
    addForm.reset()
  }

  function focusAddPath() {
    addForm.focusPath()
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Column {
    visible: root.currentFolder && root.currentFolder.problem
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: "FOLDER ERRORS"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      text: root.currentFolder
        ? "\uf07b  " + (root.currentFolder.configuredLabel
          || root.currentFolder.label) : ""
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      visible: root.syncthing && !root.syncthing.statusFresh
      width: parent.width
      text: "Last reported errors; current status is unavailable."
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }

    Text {
      width: parent.width
      text: root.controller.folderErrorText(root.currentFolder)
      textFormat: Text.PlainText
      color: root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }

    Text {
      width: parent.width
      text: root.shownErrorCount < root.totalErrorCount
        ? "Showing " + root.shownErrorCount + " of " + root.totalErrorCount
          + " current errors. Open Web UI for the full list."
        : "Showing " + root.shownErrorCount + " current error"
          + (root.shownErrorCount === 1 ? "." : "s.")
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }

  PanelSectionHeader {
    text: "FOLDERS"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  RowLayout {
    width: parent.width
    spacing: Style.space(6)

    SyncshellDropdown {
      id: folderSelector
      visible: root.controller.folderRows.length > 0
      Layout.fillWidth: true
      Layout.preferredHeight: Style.spacing.controlHeight
      showLabel: false
      rowHeight: Style.spacing.controlHeight
      value: root.controller.currentFolderId
      options: root.controller.folderOptions()
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) {
        root.controller.currentFolderId = value
        folderSelector.value = Qt.binding(function() { return root.controller.currentFolderId })
      }
    }

    TooltipButton {
      iconText: "\uf067"
      Layout.preferredWidth: Style.spacing.controlHeight
      Layout.preferredHeight: Style.spacing.controlHeight
      helpText: "Add folder"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      iconSize: Style.font.icon
      horizontalPadding: Style.space(7)
      verticalPadding: Style.space(3)
      enabled: root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
      onClicked: root.controller.addOpen
        ? root.controller.closeAddFolder() : root.controller.openAddFolder()
    }

    TooltipButton {
      visible: root.controller.folderRows.length > 0
      iconText: "\uf1e0"
      Layout.preferredWidth: Style.spacing.controlHeight
      Layout.preferredHeight: Style.spacing.controlHeight
      helpText: "Share folder"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconSize: Style.font.icon
      horizontalPadding: Style.space(7)
      verticalPadding: Style.space(3)
      enabled: root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
      onClicked: root.controller.toggleFolderSharing()
    }

    BusyButton {
      readonly property var targetFolder: root.controller.currentFolder()
      readonly property bool mutationBusy: root.syncthing
        && root.syncthing.folderMutationBusy
      readonly property bool targetBusy: mutationBusy
        && root.syncthing.folderMutationId === root.controller.currentFolderId
        && (root.syncthing.folderMutationAction === "link"
          || root.syncthing.folderMutationAction === "unlink")
      visible: root.controller.folderRows.length > 0
      Layout.preferredWidth: Style.spacing.controlHeight
      Layout.preferredHeight: Style.spacing.controlHeight
      iconText: targetBusy ? "\uf110"
        : (targetFolder && targetFolder.paused ? "\uf0c1" : "\uf00d")
      busy: targetBusy
      tooltipText: targetFolder
        ? (targetFolder.paused
          ? "Link folder"
          : "Unlink folder")
        : "Select a folder"
      bordered: true
      foreground: targetFolder && targetFolder.paused
        ? root.success : root.urgent
      disabledForeground: root.dim
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      iconSize: Style.font.icon
      horizontalPadding: Style.space(6)
      verticalPadding: Style.space(4)
      canActivate: targetFolder && root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
      onClicked: root.controller.requestFolderLinkChange(
        targetFolder, targetFolder.paused)
    }
  }

  FolderSharingForm {
    id: folderSharingForm
    visible: root.controller.folderShareOpen
    controller: root.controller
    syncthing: root.syncthing
    foreground: root.foreground
    urgent: root.urgent
    warning: root.controller.warning
    fontFamily: root.fontFamily
  }

  PanelSectionHeader {
    visible: root.controller.pendingOfferRows.length > 0
    text: "PENDING FOLDER REQUESTS"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  RowLayout {
    visible: root.controller.pendingOfferRows.length > 0
    width: parent.width
    spacing: Style.space(6)

    SyncshellDropdown {
      id: pendingOfferSelector
      Layout.fillWidth: true
      Layout.preferredHeight: Style.spacing.controlHeight
      showLabel: false
      rowHeight: Style.spacing.controlHeight
      value: root.controller.selectedPendingOffer
      options: root.controller.pendingOfferRows
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) {
        root.controller.selectedPendingOffer = value
        pendingOfferSelector.value = Qt.binding(function() { return root.controller.selectedPendingOffer })
      }
    }

    TooltipButton {
      text: "ACCEPT"
      Layout.preferredHeight: Style.spacing.controlHeight
      helpText: "Configure offered folder request"
      bordered: true
      foreground: root.success
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(6)
      verticalPadding: Style.space(4)
      enabled: root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
        && root.controller.selectedPendingOffer !== ""
      onClicked: root.controller.acceptPendingFolderOffer(
        root.controller.selectedPendingOffer)
    }
  }

  AddFolderForm {
    id: addForm
    visible: root.controller.addOpen
    controller: root.controller
    syncthing: root.syncthing
    folderPickerRunning: root.controller.folderPickerRunning
    foreground: root.foreground
    dim: root.dim
    urgent: root.urgent
    warning: root.controller.warning
    fontFamily: root.fontFamily
  }

  PanelSeparator {
    foreground: root.foreground
  }

  RemoteDevices {
    id: remoteDevices
    width: parent.width
    controller: root.controller
    syncthing: root.syncthing
    foreground: root.foreground
    dim: root.dim
    urgent: root.urgent
    warning: root.controller.warning
    success: root.success
    fontFamily: root.fontFamily
  }

  PanelSeparator {
    foreground: root.foreground
  }

  RowLayout {
    width: parent.width
    spacing: Style.space(6)

    PanelSectionHeader {
      text: "INSTALLATION"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      text: "󰋽"
      textFormat: Text.PlainText
      color: root.installationStatusColor()
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon

      HoverHandler { id: installationStatusHover }
      SyncshellToolTip {
        visible: installationStatusHover.hovered
        text: root.installationStatusText()
        textFormat: Text.StyledText
        fontFamily: root.fontFamily
      }
    }

    Item { Layout.fillWidth: true }

    TooltipButton {
      id: installationHelp
      Layout.preferredWidth: Style.spacing.controlHeight
      Layout.preferredHeight: Style.spacing.controlHeight
      iconText: "\uf128"
      helpText: "Open Syncthing installation\n"
        + "and removal documentation"
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconSize: Style.font.body
      horizontalPadding: Style.space(5)
      verticalPadding: Style.space(3)
      bordered: true
      focusable: true
      onClicked: root.controller.openSyncthingPackageDocumentation()
    }
  }

  InfoPair {
    label: "Executable"
    value: root.syncthing && root.syncthing.executablePath !== ""
      ? root.syncthing.executablePath : "—"
    elideMode: Text.ElideLeft
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: text !== ""
    width: parent.width
    text: {
      if (!root.syncthing) return "Installation status unavailable."
      if (root.syncthing.installationState === "existing") return ""
      if (root.syncthing.installationState === "incomplete") {
        return "Repair or remove the incomplete installation manually."
      }
      if (root.syncthing.installationState === "missing") {
        return "Installs through Omarchy. Removal is manual."
      }
      return "Checking installation."
    }
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    wrapMode: Text.NoWrap
  }

  Text {
    visible: root.syncthing && root.syncthing.packageStatus !== ""
    width: parent.width
    text: root.syncthing ? root.syncthing.packageStatus : ""
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    wrapMode: Text.NoWrap
  }

  Button {
    visible: root.syncthing && root.syncthing.canInstall
    text: "Install Syncthing"
    bordered: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    enabled: root.syncthing && root.syncthing.canInstall
    onClicked: root.controller.installationAction()
  }

}
