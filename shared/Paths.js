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

function resolveFolderPath(value, homePath) {
    var path = String(value || "");
    if (path === "~")
        return homePath;
    if (path.indexOf("~/") === 0)
        return homePath + path.slice(1);
    if (path.charAt(0) === "/" || !homePath)
        return path;
    return homePath + "/" + path;
}
