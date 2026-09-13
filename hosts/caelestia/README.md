# Caelestia adapter

Syncshell supports Caelestia Shell commit
`1d0e5a588c61f1d905eba5fe8446ec222d37f50c` on Arch Linux with its pinned
Quickshell and CLI revisions. The status entry and popout use one shell-owned
native core. The adapter extends Caelestia's compiled bar configuration so the
entry remains a normal configurable status item.

## Install and update

Apply the adapter to the clean pinned checkout before building Caelestia:

```bash
integrations/caelestia/apply.sh /path/to/pinned/caelestia-checkout
cmake -S /path/to/pinned/caelestia-checkout \
  -B /path/to/pinned/caelestia-checkout/build -G Ninja
cmake --build /path/to/pinned/caelestia-checkout/build
sudo cmake --install /path/to/pinned/caelestia-checkout/build
```

The overlay bundles the prebuilt core and required QML files. Syncshell performs
no runtime build or download. Update by applying a newer Syncshell checkout to
a fresh checkout at the same supported Caelestia revision and rebuilding.

## Remove

Rebuild and install the unmodified pinned Caelestia checkout. Syncthing
configuration, service state, and folder contents are not changed.
