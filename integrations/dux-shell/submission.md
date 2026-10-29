# DMS registry submission

The upstream requirements are in
[CONTRIBUTING.md](https://github.com/duxlabs-dev/dux-plugin-registry/blob/master/CONTRIBUTING.md).
The package targets the pinned DMS 2.0.0 (Dux Shell) manifest/SDK and its
`qs.DCommon.Widgets` controls, not development APIs.

- Registry file: `plugins/ilyazar-syncshell.json`.
- Package and registry ID/name must match: `syncshell` / `Syncshell`.
- Repository: `https://github.com/omarchy-QOL/syncshell`.
- Monorepo path: `dist/dux-shell` on the default branch.
- Capabilities: daemon, bar widget, monitoring; category: monitoring.
- External dependency: Syncthing. Clipboard and file opening use DMS tools.
- Package permissions: process, network, settings read/write.
- Add a direct, reachable screenshot URL from the actual DMS panel, ideally
  with a side form open on the default theme. Do not use an Omarchy screenshot.
- State only the compositors, distributions and architectures actually tested.

DMS clones the whole source repository and links the package subdirectory.
It does not run assembly. Measure clone size before submission and discuss an
actual size blocker rather than adding a second repository automatically.

The current reachable local branch/tag/origin history repacks to about
191 MiB (200,639,694 bytes), before adding the DMS release payload. This is an
estimate, not a measured marketplace download: the actual clone depends on
upstream refs and the manager's clone flags. Recheck before submission.

After the release package and screenshot are available upstream, run the
registry's validators in a registry checkout:

```sh
python3 .github/generate.py --validate
python3 .github/validate_links.py
```

Recheck name/ID availability and the duplicate-plugin policy before filing.
Explain the full folder/device/sharing workflow improvements over a read-only
port where relevant, and disclose meaningful AI assistance in the PR.
The maintainer must review and test the result. No registry PR, publication or
installation is authorized by assembling this package.
