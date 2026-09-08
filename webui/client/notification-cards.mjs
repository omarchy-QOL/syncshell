// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0
// prose retained from the existing Syncthing notification cards
export const notificationCards = {
    "channelNotification": {
        "paragraphs": [
            "Automatic upgrade now offers the choice between stable releases and release candidates.",
            "Release candidates contain the latest features and fixes. They are similar to the traditional bi-weekly Syncthing releases.",
            "Stable releases are delayed by about two weeks. During this time they go through testing as release candidates.",
            "You can read more about the two release channels at the link below.",
            "You can change your choice at any time in the Settings dialog."
        ],
        "severity": "success",
        "title": "Automatic upgrades",
        "actions": [
            "Settings",
            "OK"
        ],
        "link": "https://docs.syncthing.net/users/releases.html"
    },
    "fsWatcherNotification": {
        "paragraphs": [
            "Continuously watching for changes is now available within Syncthing. This will detect changes on disk and issue a scan on only the modified paths. The benefits are that changes are propagated quicker and that less full scans are required.",
            "Do you want to enable watching for changes for all your folders?",
            "Additionally the full rescan interval will be increased (times 60, i.e. new default of 1h). You can also configure it manually for every folder later after choosing No.",
            "Warning: If you are using an external watcher like {%syncthingInotify%}, you should make sure it is deactivated."
        ],
        "severity": "success",
        "title": "Watching for Changes",
        "actions": [
            "Yes",
            "No"
        ],
        "link": "https://docs.syncthing.net/users/syncing.html#scanning"
    },
    "crAutoEnabled": {
        "paragraphs": [
            "Syncthing now supports automatically reporting crashes to the developers. This feature is enabled by default."
        ],
        "severity": "success",
        "title": "Automatic Crash Reporting",
        "actions": [
            "Disable Crash Reporting",
            "OK"
        ],
        "link": "https://docs.syncthing.net/users/crashrep.html"
    },
    "crAutoDisabled": {
        "paragraphs": [
            "Syncthing now supports automatically reporting crashes to the developers. This feature is enabled by default.",
            "However, your current settings indicate you might not want it enabled. We have disabled automatic crash reporting for you."
        ],
        "severity": "success",
        "title": "Automatic Crash Reporting",
        "actions": [
            "Enable Crash Reporting",
            "OK"
        ],
        "link": "https://docs.syncthing.net/users/crashrep.html"
    },
    "authenticationUserAndPassword": {
        "paragraphs": [
            "Username/Password has not been set for the GUI authentication. Please consider setting it up.",
            "If you want to prevent other users on this computer from accessing Syncthing and through it your files, consider setting up authentication."
        ],
        "severity": "success",
        "title": "GUI Authentication: Set User and Password",
        "actions": [
            "Settings",
            "OK"
        ]
    }
};
