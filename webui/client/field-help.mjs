// explanations retained from the accepted Syncshell UI
export const fieldHelp = {
    "Global/local State": {icon: "fa fa-fw fa-circle",
        help: "Shows the global totals alongside the folder status. Separate rows show global and local " +
            "contents when details are needed; ignore patterns can make the totals differ even when up " +
            "to date."},
    "Global State": {icon: "fas fa-fw fa-globe",
        help: "The latest known versions of files across the sharing devices. These totals describe the " +
            "contents this folder would have when fully synchronized, before local ignore rules."},
    "Local State": {icon: "fas fa-fw fa-home",
        help: "The files and data Syncthing currently tracks in this folder on this device. These totals " +
            "can differ from the global contents during synchronization or because of ignore patterns."},
    "Out of Sync Items": {icon: "fas fa-fw fa-exchange-alt",
        help: "Items still needed by this remote device across shared folders, including pending " +
            "deletions. Click the count to view the remaining work."},
    "Altered by ignoring deletes.": {icon: "fas fa-question-circle",
        help: "Deletion requests from other devices are ignored, so files deleted elsewhere can remain in " +
            "this folder."},
    "Last Scan": {icon: "far fa-fw fa-clock",
        help: "When Syncthing last scanned this folder for local changes. This is a scan timestamp, not " +
            "the time of the last file transfer."},
    "Error": {icon: "fas fa-fw fa-exclamation-triangle",
        help: "The problem Syncthing reports for this folder. Hover over the message to read the full " +
            "details."},
    "Failed Items": {icon: "fas fa-fw fa-exclamation-circle",
        help: "Items Syncthing could not synchronize. Click the count to see the affected paths and their " +
            "individual errors."},
    "Locally Changed Items": {icon: "fas fa-fw fa-exclamation-circle",
        help: "Local changes in a receive-only folder that are not sent to other devices, or unexpected " +
            "local items in a receive-encrypted folder. Click the value to inspect them."},
    "Scan Time Remaining": {icon: "fas fa-fw fa-hourglass-half",
        help: "Estimated time left for the current scan, calculated from the remaining data and current " +
            "scanning rate. This estimates scanning, not synchronization."},
    "Latest Change": {icon: "fas fa-fw fa-exchange-alt",
        help: "The most recent file synchronized here, as reported by Syncthing. Hover over the filename " +
            "for its full path, update or deletion, and timestamp."},
    "Rescans": {icon: "fas fa-fw fa-refresh",
        help: "Detects local changes through periodic full scans and filesystem watching. The clock shows " +
            "the scan interval; the eye shows whether watching is enabled."},
    "File Versioning": {icon: "fa fa-fw fa-files-o",
        help: "Keeps older copies when changes from another device replace or delete files here. It does " +
            "not archive changes you make locally; retention depends on the selected versioning method."},
    "Ignore Permissions": {icon: "far fa-fw fa-minus-square",
        help: "File permission changes are not synchronized for this folder. File contents still " +
            "synchronize normally."},
    "Folder Path": {icon: "fas fa-fw fa-folder-open",
        help: "Full path to your Syncthing folder on the file system of this device. Hover over the value " +
            "to see the complete path."},
    "Folder Type": {icon: "fas fa-fw fa-folder",
        help: "Controls how changes travel: Send and Receive exchanges changes both ways; Send Only " +
            "publishes local changes; Receive Only accepts remote changes without publishing local " +
            "edits; Receive Encrypted stores protected data without decrypting it."},
    "Folder ID": {icon: "fas fa-fw fa-info-circle",
        help: "Identifies this shared folder across devices. Every device sharing it must use exactly the " +
            "same ID, including letter case."},
    "Block Indexing": {icon: "far fa-fw fa-book",
        help: "Keeps an index of data blocks so Syncthing can reuse existing content from other files, " +
            "including other folders. Disabling it saves database space but can increase transfer " +
            "bandwidth."},
    "File Pull Order": {icon: "fas fa-fw fa-sort",
        help: "Sets the download priority for files needed from other devices. Ordering applies only to " +
            "files already discovered during scanning."},
    "Local State (Total)": {icon: "fas fa-fw fa-home",
        help: "Local files and data indexed across all folders on this device. These totals do not " +
            "indicate whether every folder is synchronized."},
    "Listeners": {icon: "fas fa-fw fa-sitemap",
        help: "Listening services that accept incoming device connections. Shows working services out of " +
            "the total. Click the count for addresses and errors."},
    "Discovery": {icon: "fas fa-fw fa-map-signs",
        help: "Services used to find other devices. Shows working discovery methods out of the total. " +
            "Click the count for details; discovery success does not mean a device is connected."},
    "Uptime": {icon: "far fa-fw fa-clock",
        help: "Time since this Syncthing process started. Reloading the Web UI does not reset it."},
    "Identification": {icon: "fas fa-qrcode",
        help: "Show the full device ID and QR code for this remote device."},
    "Version": {icon: "fas fa-fw fa-tag",
        help: "Syncthing client version reported by this remote device."},
    "Device Status": {icon: "fa fa-fw",
        help: "Connection and synchronization status of this remote device."},
    "Sync Status": {icon: "fas fa-fw fa-cloud",
        help: "Last known synchronization progress across folders shared with this device. An offline " +
            "device may have changed since its last connection."},
    "Address": {icon: "fas fa-fw fa-link",
        help: "Address used for the current connection, or configured and discovered addresses to try " +
            "while disconnected. Connection errors appear beside each address."},
    "Last seen": {icon: "fas fa-fw fa-eye",
        help: "When this device was last seen connected. Never means no previous connection is recorded."},
    "Number of Connections": {icon: "fas fa-fw fa-random",
        help: "Current connections to this device: one primary connection plus any additional " +
            "connections."},
    "Introduced By": {icon: "far fa-fw fa-handshake-o",
        help: "The device that introduced this peer to this machine."},
    "Compression": {icon: "fas fa-fw fa-compress",
        help: "Whether messages sent to this device are compressed: metadata only, all data, or off."},
    "Allowed Networks": {icon: "fas fa-fw fa-filter",
        help: "Connections to this device are restricted to these networks."},
    "Introducer": {icon: "far fa-fw fa-thumbs-up",
        help: "Automatically follows the devices this peer shares folders with."},
    "Auto Accept": {icon: "fa fa-fw fa-level-down",
        help: "Automatically accepts folders offered by this device and adds them locally using the " +
            "default folder path."},
    "Untrusted": {icon: "fa fa-fw fa-user-secret",
        help: "Only encrypted folder data may be shared with this device."},
    "Folders": {icon: "fas fa-folder",
        help: "Folders this machine shares with this device. Select a folder to edit its sharing " +
            "settings."},
    "Encrypted": {icon: "fa fa-lock",
        help: "Folder data is encrypted for this remote device."},
    "Not Sharing": {icon: "fas fa-exclamation-circle",
        help: "The remote device has not accepted sharing this folder."},
    "Paused": {icon: "fas fa-pause",
        help: "The remote device has paused this folder."},
    "Remote GUI": {icon: "fas fa-desktop",
        help: "Remote GUI address is unavailable. A direct connection to this device is required."},
    "Pause": {icon: "fas fa-pause",
        help: "Temporarily pause synchronization with this remote device."},
    "Resume": {icon: "fas fa-play",
        help: "Resume synchronization with this remote device."},
    "Edit": {icon: "fas fa-pencil-alt",
        help: "Edit the configuration for this remote device."},
};
