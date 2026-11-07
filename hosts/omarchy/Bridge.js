.pragma library

// Replacement bars give widgets a shell whose serviceFor returns null, so the
// service publishes itself here. This file must sit beside Service.qml and the
// widget that reads it: a library imported from elsewhere would be a separate copy.
var active = null

function publish(service) { active = service }
function current() { return active }
// A retired service must not clear a replacement published during hot reload.
function clear(service) { if (active === service) active = null }
