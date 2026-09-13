# DankMaterialShell adapter

Syncshell supports DankMaterialShell 1.5.3 through 1.6.1 on Arch Linux with
Quickshell 0.3.1. The composite plugin owns one native core in its daemon and
shares that service with every horizontal or vertical bar widget instance.

## Install and update

Build a complete plugin directory, then install it through DMS:

```bash
integrations/dankmaterialshell/assemble.sh /tmp/Syncshell
dms plugins install /tmp/Syncshell
```

To update, assemble from the new checkout, uninstall the old plugin, install
the new directory, and restart `dms.service`. The plugin bundle includes the
prebuilt core; installation performs no build or download.

## Remove

```bash
dms plugins uninstall syncshell
```

Removal deletes only the adapter. Syncthing configuration, service state, and
folder contents remain owned by Syncthing and the user.
