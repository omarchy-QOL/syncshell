.pragma library

function localFilePath(value) {
    var path = String(value || "");
    if (path.indexOf("file:") !== 0)
        return path;
    var url = new URL(path);
    if (url.protocol !== "file:" || (url.hostname && url.hostname !== "localhost"))
        return "";
    return decodeURIComponent(url.pathname);
}
