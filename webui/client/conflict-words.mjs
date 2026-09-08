export const conflictWords = {
    "de": {
        "Location": "Speicherort",
        "Actions": "Aktionen",
        "Conflict files": "Konfliktdateien",
        "Current file": "Aktuelle Datei",
        "Conflict copies": "Konfliktkopien",
        "Conflict copy": "Konfliktkopie",
        "Recheck files in folder": "Dateien im Ordner erneut prüfen",
        "Recheck all files": "Alle Dateien erneut prüfen",
        "Autoresolve": "Automatisch auflösen",
        "Restore original name": "Ursprünglichen Namen wiederherstellen",
        "Rename": "Umbenennen",
        "Cancel": "Abbrechen",
        "From": "Von",
        "To": "Nach",
        "Rename the selected conflict file to the original name. Other conflict files remain. An existing file will never be overwritten.": "Die ausgewählte Konfliktdatei erhält den ursprünglichen Namen. Andere Konfliktdateien bleiben erhalten. Eine vorhandene Datei wird niemals überschrieben.",
        "File renamed; Syncthing status refreshed.": "Datei umbenannt; Syncthing-Status aktualisiert.",
        "Open folder": "Ordner anzeigen",
        "No matches": "Keine Treffer",
        "Search filenames or paths": "Dateinamen oder Pfade suchen",
        "Missing current file": "Aktuelle Datei fehlt",
        "No conflict files remain": "Keine Konfliktdateien mehr vorhanden",
        "To keep a conflict file, rename it to:": "Zum Behalten eine Konfliktdatei umbenennen in:",
        "The latest Syncthing index has no usable file at the original name. Conflict files are ordinary files with a conflict marker in their names. Rename the version you want to keep, or delete unwanted conflict files, then recheck. Rechecking alone does not rename or delete files.": "Im aktuellen Syncthing-Index gibt es keine verwendbare Datei unter dem ursprünglichen Namen. Konfliktdateien sind normale Dateien mit einer Konfliktmarkierung im Namen. Benennen Sie die gewünschte Version um oder löschen Sie unerwünschte Konfliktdateien. Prüfen Sie danach erneut. Die erneute Prüfung benennt keine Dateien um und löscht nichts.",
        "Not available locally": "Lokal nicht verfügbar",
        "Waiting for Syncthing to download this file": "Warten auf den Download durch Syncthing",
        "Open in file manager": "Im Dateimanager anzeigen"
    }
};
export const conflictTranslator = locale => key => conflictWords[locale.language]?.[key] || locale.t(key);
