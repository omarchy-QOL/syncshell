# DankMaterialShell adapter

Syncshell supports DankMaterialShell 1.5.3 or newer on Arch Linux. The
composite plugin owns one native core in its daemon and shares that service
with every horizontal or vertical bar widget instance.

## Install and update

Install or update from the repository root:

```bash
./install.sh --shell dms
```

The installer assembles the plugin, enables its widget, and restarts
`dms.service`. The plugin bundle includes the prebuilt core.

## Remove

```bash
dms plugins uninstall syncshell
```

Removal deletes only the adapter. Syncthing configuration, service state, and
folder contents remain owned by Syncthing and the user.
