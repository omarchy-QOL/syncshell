.pragma library

function contains(parent, child) {
    for (var item = child; item; item = item.parent) if (item === parent) return true;
    return false;
}

function available(item, root) {
    if (!item || item.width <= 0 || item.height <= 0) return false;
    for (var node = item; node; node = node.parent) {
        if (!node.visible || !node.enabled) return false;
        if (node === root) return true;
    }
    return false;
}

function controls(root) {
    var result = [];
    function visit(item) {
        if (!item.visible || !item.enabled) return;
        if (item.navigationControl === true) {
            if (available(item, root) && !item.busy) result.push(item);
            return;
        }
        for (var index = 0; index < item.children.length; index++) visit(item.children[index]);
    }
    visit(root);
    return result;
}

function find(root, key) {
    if (root.objectName === key && available(root, root)) return root;
    for (var index = 0; index < root.children.length; index++) {
        var child = root.children[index];
        if (!child.visible) continue;
        var result = find(child, key);
        if (result) return result;
    }
    return null;
}

function move(root, focused, dx, dy) {
    var rows = controls(root), current = rows.find(row => contains(row, focused));
    if (!current) return rows[0] || null;
    var origin = current.mapToItem(root, current.width / 2, current.height / 2);
    var best = null, score = Infinity;
    rows.forEach(function (row) {
        if (row === current) return;
        var point = row.mapToItem(root, row.width / 2, row.height / 2);
        var x = point.x - origin.x, y = point.y - origin.y;
        if (dx && x * dx <= 1 || dy && y * dy <= 1) return;
        var primary = dx ? Math.abs(x) : Math.abs(y);
        var secondary = dx ? Math.abs(y) : Math.abs(x);
        // Horizontal movement stays in a row; vertical movement favors nearby rows.
        var distance = primary + secondary * (dx ? 8 : 0.3);
        if (distance < score) { score = distance; best = row; }
    });
    return best || current;
}
