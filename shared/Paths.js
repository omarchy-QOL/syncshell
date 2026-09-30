.pragma library

function localPath(url) {
    var value = String(url || "");
    if (value.indexOf("file://") === 0)
        value = value.slice(7);
    return decodeURIComponent(value);
}
