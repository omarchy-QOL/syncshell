# Illogical Impulse adapter

Syncshell supports Illogical Impulse commit
`42d0aae17b744a38cd05c9044c189bfc9b13869a` on Arch Linux. Its native
horizontal bar item works with both top and bottom bar placement. One shell
singleton owns the bundled native core; opening the popup on another monitor
does not create another session.

## Install and update

Install or update from the repository root:

```bash
./install.sh --shell ii
```

The installer clones the pinned upstream source, applies the adapter, backs up
replaced files, and installs the QML service, bar item, popup, and prebuilt
core. Restart the shell when it is not managed by a user service.

## Remove

Restore the pinned upstream checkout or reinstall its unmodified configuration.
This removes only the adapter files and bar insertion. Syncthing configuration
and folder contents are not changed.
