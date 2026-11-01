.pragma library

// JS URLs are stable across this loader's QML generations.
var owner = null;
var views = {};

function claim(service) {
    var previous = owner;
    if (previous === service) return null;
    owner = service;
    if (previous) previous.retire();
    return previous;
}
function view(key, initial) {
    if (!views[key]) views[key] = initial;
    return views[key];
}
function save(key, value) { views[key] = value; }
