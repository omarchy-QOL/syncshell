// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function compactNumber(input) {
    if (!Number.isFinite(input) || input < 0) {
        return '-';
    }
    var units = [[1e9, 'B'], [1e6, 'M'], [1e3, 'k']];
    for (var i = 0; i < units.length; i++) {
        if (input >= units[i][0]) {
            return (Math.floor(input / (units[i][0] / 10)) / 10)
                .toFixed(1) + units[i][1];
        }
    }
    return input.toLocaleString();
}

export function unitPrefixed(input, binary) {
    if (input === undefined || isNaN(input)) {
        return '0 ';
    }
    var factor = 1000;
    var i = '';
    if (binary) {
        factor = 1024;
        i = 'i';
    }
    if (input > factor * factor * factor * factor * 1000) {
        // Don't show any decimals for more than 4 digits
        input /= factor * factor * factor * factor;
        return input.toLocaleString(undefined, { maximumFractionDigits: 0 }) + ' T' + i;
    }
    // Show 3 significant digits (e.g. 123T or 2.54T)
    if (input > factor * factor * factor * factor) {
        input /= factor * factor * factor * factor;
        return input.toLocaleString(undefined, { maximumSignificantDigits: 3 }) + ' T' + i;
    }
    if (input > factor * factor * factor) {
        input /= factor * factor * factor;
        if (binary && input >= 1000) {
            return input.toLocaleString(undefined, { maximumFractionDigits: 0 }) + ' G' + i;
        }
        return input.toLocaleString(undefined, { maximumSignificantDigits: 3 }) + ' G' + i;
    }
    if (input > factor * factor) {
        input /= factor * factor;
        if (binary && input >= 1000) {
            return input.toLocaleString(undefined, { maximumFractionDigits: 0 }) + ' M' + i;
        }
        return input.toLocaleString(undefined, { maximumSignificantDigits: 3 }) + ' M' + i;
    }
    if (input > factor) {
        input /= factor;
        var prefix = ' k';
        if (binary) {
            prefix = ' K';
        }
        if (binary && input >= 1000) {
            return input.toLocaleString(undefined, { maximumFractionDigits: 0 }) + prefix + i;
        }
        return input.toLocaleString(undefined, { maximumSignificantDigits: 3 }) + prefix + i;
    }
    return Math.round(input).toLocaleString() + ' ';
};
