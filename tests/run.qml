import QtQuick
import "../hosts/omarchy/models/PanelModel.js" as PanelModel
import "../hosts/omarchy/models/SettingsModel.js" as SettingsModel
import "../hosts/omarchy/models/FacadeModel.js" as FacadeModel
import "../shared"
import "../shared/Paths.js" as Paths

QtObject {
    id: root

    property int rescanCompletions: 0
    property RescanTracker rescanTracker: RescanTracker {
        onCompleted: root.rescanCompletions++
    }

    function compare(actual, expected, name) {
        if (JSON.stringify(actual) !== JSON.stringify(expected)) {
            throw new Error(name + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
        }
    }

    function testLocalFilePath() {
        compare(Paths.localFilePath("file:///tmp/a%20b%23c"), "/tmp/a b#c", "decoded file URL");
        compare(Paths.localFilePath("/tmp/folder"), "/tmp/folder", "plain local path");
        compare(Paths.localFilePath("file://remote/tmp/folder"), "", "remote file URL refused");
    }

    function testFolderPathResolution() {
        compare(PanelModel.resolveFolderPath("~", "/home/test"), "/home/test", "home path");
        compare(PanelModel.resolveFolderPath("~/docs", "/home/test"), "/home/test/docs", "home-relative path");
        compare(PanelModel.resolveFolderPath("docs", "/home/test"), "/home/test/docs", "relative path");
        compare(PanelModel.resolveFolderPath("/tmp/docs", "/home/test"), "/tmp/docs", "absolute path");
    }

    function testFolderErrorDetails() {
        var details = [
            {
                path: "repo",
                error: "delete dir: contains ignored files"
            },
            {
                path: "repo/child",
                error: "delete dir: contains ignored files"
            },
            {
                path: "other",
                error: "permission denied"
            }
        ];
        var service = {
            folders: [
                {
                    id: "failed",
                    path: "/tmp/failed",
                    label: "Named folder"
                },
                {
                    id: "healthy",
                    path: "/tmp/healthy"
                }
            ],
            folderStatuses: FacadeModel.folderStatuses([
                {
                    id: "failed",
                    status: {
                        state: "idle",
                        pullErrors: 19,
                        errors: details
                    }
                },
                {
                    id: "healthy",
                    status: {
                        state: "idle",
                        errors: []
                    }
                }
            ])
        };
        var rows = PanelModel.buildFolderRows(service, "/home/test");
        var failed = PanelModel.folderById(rows, "failed");
        compare(failed.errorDetails, details, "per-file errors reach the panel");
        compare(failed.errorCount, 19, "complete error count reaches the panel");
        compare(PanelModel.folderMeta(failed), details[0].error + " · Named folder", "card uses the available reason");
        compare(PanelModel.folderErrorText(failed), "delete dir: contains ignored files\n\nrepo\nrepo/child\n\n" + "permission denied\n\nother", "identical reasons share paths");
        compare(PanelModel.folderErrorText(PanelModel.folderById(rows, "healthy")), "", "healthy selection has no errors");
        failed.error = "folder unavailable";
        compare(PanelModel.folderMeta(failed), "folder unavailable · Named folder", "folder summary takes precedence");
        compare(PanelModel.folderErrorText({
            problem: true,
            errorDetails: [
                {
                    path: "<file>",
                    error: "__proto__"
                }
            ]
        }), "__proto__\n\n<file>", "error text remains data");
    }

    function testPendingOffers() {
        var service = {
            pendingFolders: {
                plain: {
                    offeredBy: {
                        remote: {
                            label: "Documents"
                        }
                    }
                },
                encrypted: {
                    offeredBy: {
                        remote: {
                            receiveEncrypted: true
                        }
                    }
                },
                mixed: {
                    offeredBy: {
                        a: {},
                        b: {
                            remoteEncrypted: true
                        }
                    }
                }
            },
            devices: [
                {
                    deviceID: "remote",
                    name: "Phone"
                }
            ]
        };
        compare(PanelModel.pendingOfferOptions(service), [
            {
                value: JSON.stringify(["plain", "remote"]),
                label: "Documents from Phone"
            }
        ], "only unencrypted offers are actionable");
        compare(PanelModel.encryptedPendingOfferCount(service), 2, "encrypted count matches hidden offers");
    }

    function testSettingsModel() {
        var current = 'version = 2\n[style]\nicon_style = "themed"\n' + 'web_ui_theme = "default"\n[service]\nservice_state = "disabled"\n' + 'probe_interval_seconds = 27\n';
        var expected = {
            error: "",
            version: 2,
            iconStyle: "themed",
            webUiTheme: "default",
            serviceState: "disabled",
            probeIntervalSeconds: 27
        };
        compare(SettingsModel.parse(current), expected, "current settings");
        compare(SettingsModel.defaults(), {
            iconStyle: "themed",
            webUiTheme: "omarchy",
            serviceState: "enabled",
            probeIntervalSeconds: 15
        }, "implicit defaults");
        ["default", "modern", "omarchy"].forEach(function (theme) {
            compare(SettingsModel.parse(current.replace('"default"', '"' + theme + '"')).webUiTheme, theme, "valid Web UI " + theme);
        });
        var invalid = [current.replace('"default"', '"oomarchy"'), current.replace('"default"', '"dfault"'), current.replace('"themed"', '"theme"'), current.replace('"disabled"', '"disable"'), current.replace('[service]', '[servcie]'), current + '[future]\nvalue = [1,,]\n', current.replace('icon_style', 'icon_stlye'), current.replace('"default"', 'default'), current.replace('27', '"27"'), current.replace('27', '0'), current.replace('27', '3601'), current.replace('27', '1.5'), current + 'service_state = "enabled"\n', current + '[style]\n', current.replace('version = 2', 'version = "2"'), current.replace('version = 2', 'version = 3'), current.replace('web_ui_theme = "default"\n', ''), current.replace('version = 2', 'version = 2\nversion = 2')];
        invalid.forEach(function (raw, index) {
            compare(!!SettingsModel.parse(raw).error, true, "invalid settings " + index);
        });
        var older = current.replace('version = 2', 'version = 1 # owner comment');
        compare(!!SettingsModel.parse(older).error, true, "old runtime format refused");
        compare(SettingsModel.migrate(older.replace('"themed"', '"theme"')).error,
                "icon_style must be branded or themed",
                "migration propagates old-schema validation failure");
        var migrated = SettingsModel.migrate(older);
        compare(migrated.values, expected, "old preferences survive");
        compare(migrated.text, current.replace('version = 2', 'version = 2 # owner comment'), "comments survive");
        compare(migrated.additions, [], "no redundant defaults");
        var legacy = '# owner comment\nicon_style = "branded"\n' + 'web_ui_theme = "omarchy"\n';
        migrated = SettingsModel.migrate(legacy);
        compare(migrated.values, {
            error: "",
            version: 2,
            iconStyle: "branded",
            webUiTheme: "omarchy",
            serviceState: "enabled",
            probeIntervalSeconds: 15
        }, "unversioned migration keeps old defaults");
        compare(migrated.additions.length, 2, "missing defaults are listed");
        compare(migrated.text.indexOf('# owner comment') >= 0, true, "legacy comment survives");
        var serviceFirst = 'version = 1\n[service]\nservice_state = "disabled"\n' + '[style]\nicon_style = "themed"\nweb_ui_theme = "modern"\n';
        migrated = SettingsModel.migrate(serviceFirst.replace(/\n/g, "\r\n"));
        compare(migrated.values.probeIntervalSeconds, 15, "service before style");
        compare(migrated.values.serviceState, "disabled", "partial service preserved");
        compare(migrated.text.replace(/\r\n/g, "").indexOf("\n"), -1, "CRLF preserved");
    }

    function testTruncationWarning() {
        compare(FacadeModel.truncationWarning({}), "", "complete state warning");
        compare(FacadeModel.truncationWarning({
            folderErrors: 1
        }), "", "folder detail limits are reported with the errors");
        compare(FacadeModel.truncationWarning({
            folders: 1
        }), "Some Syncthing items exceed panel limits; use the Web UI for the " + "hidden entries", "truncated state warning");
    }

    function testDriftPresentation() {
        var decision = FacadeModel.driftDecision("enabled", {
            unitFileState: "disabled",
            activeState: "inactive"
        });
        compare(decision.status, "drift", "drift status");
        compare(decision.first.side, "config", "inactive preferred side");
        compare(decision.second.side, "system", "inactive alternate side");
        compare(FacadeModel.driftDecision("enabled", {
            unitFileState: "enabled",
            activeState: "active"
        }).status, "aligned", "aligned state");
    }

    function testRescanTracker() {
        compare(rescanTracker.acceptResult({
            state: "completed",
            targetFolderIds: ["folder"],
            runningFolderIds: []
        }, []), true, "fast rescan result accepted");
        compare(rescanCompletions, 1, "fast rescan completes immediately");
        compare(rescanTracker.acceptResult({
            state: "running",
            targetFolderIds: ["folder"],
            runningFolderIds: ["other"]
        }, ["other"]), false, "unrelated running target rejected");
        compare(rescanCompletions, 1, "invalid result does not complete");
    }

    Component.onCompleted: {
        try {
            testLocalFilePath();
            testFolderPathResolution();
            testFolderErrorDetails();
            testPendingOffers();
            testSettingsModel();
            testTruncationWarning();
            testDriftPresentation();
            testRescanTracker();
            console.log("all QML model tests passed");
            Qt.exit(0);
        } catch (error) {
            console.error(error);
            Qt.exit(1);
        }
    }
}
