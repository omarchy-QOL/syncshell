.pragma library

function isAvailable(item, boundary) {
    if (!item || item.enabled === false)
        return false;
    if (item.interactive !== undefined && !item.interactive)
        return false;
    var current = item;
    while (current) {
        if (current.visible === false)
            return false;
        if (current === boundary)
            return true;
        current = current.parent;
    }
    return boundary === null || boundary === undefined;
}

function availableRows(rows, boundary) {
    var result = [];
    for (var row = 0; row < rows.length; row++) {
        var available = [];
        for (var column = 0; column < rows[row].length; column++) {
            if (isAvailable(rows[row][column], boundary))
                available.push(rows[row][column]);
        }
        if (available.length > 0)
            result.push(available);
    }
    return result;
}

function first(rows, boundary) {
    var available = availableRows(rows, boundary);
    return available.length > 0 ? available[0][0] : null;
}

function move(rows, current, dx, dy, boundary) {
    var available = availableRows(rows, boundary);
    if (available.length === 0)
        return null;

    var currentRow = -1;
    var currentColumn = -1;
    for (var row = 0; row < available.length; row++) {
        var column = available[row].indexOf(current);
        if (column >= 0) {
            currentRow = row;
            currentColumn = column;
            break;
        }
    }
    if (currentRow < 0)
        return available[0][0];

    if (dy !== 0) {
        currentRow = (currentRow + (dy > 0 ? 1 : -1) + available.length) % available.length;
        currentColumn = Math.min(currentColumn, available[currentRow].length - 1);
    } else if (dx !== 0) {
        currentColumn = (currentColumn + (dx > 0 ? 1 : -1) + available[currentRow].length) % available[currentRow].length;
    }
    return available[currentRow][currentColumn];
}

function contains(item, ancestor) {
    var current = item;
    while (current) {
        if (current === ancestor)
            return true;
        current = current.parent;
    }
    return false;
}
