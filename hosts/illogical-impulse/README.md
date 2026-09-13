# Illogical Impulse adapter

Syncshell supports Illogical Impulse commit
`42d0aae17b744a38cd05c9044c189bfc9b13869a` on Arch Linux. Its native
horizontal bar item works with both top and bottom bar placement. One shell
singleton owns the bundled native core; opening the popup on another monitor
does not create another session.

## Install and update

Apply the pinned source overlay before installing Illogical Impulse's files:

```bash
integrations/illogical-impulse/apply.sh /path/to/pinned/ii-checkout
```

The command requires a clean checkout at the documented commit. It installs
the QML service, bar item, popup, and prebuilt core into that checkout without
building or downloading Syncshell at runtime. Reapply from a new Syncshell
checkout to update, then restart the shell.

## Remove

Restore the pinned upstream checkout or reinstall its unmodified configuration.
This removes only the adapter files and bar insertion. Syncthing configuration
and folder contents are not changed.
