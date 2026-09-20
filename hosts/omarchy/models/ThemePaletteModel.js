.pragma library

var DefaultYellow = "#ebcb8b"
var DefaultGreen = "#a3be8c"
var DefaultCyan = "#26B6DB"

function defaults() {
  return {
    yellow: DefaultYellow,
    green: DefaultGreen,
    cyan: DefaultCyan
  }
}

function parse(text) {
  var palette = {}
  var lines = String(text || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].split("\t")
    if (fields.length !== 2
        || ["yellow", "green", "cyan"].indexOf(fields[0]) < 0) continue
    if (palette[fields[0]] !== undefined
        || !/^#[0-9a-fA-F]{6}$/.test(fields[1])) return null
    palette[fields[0]] = fields[1]
  }
  return palette.yellow && palette.green && palette.cyan ? palette : null
}
