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

export function duration(input, precision, language, humanize = globalThis.humanizeDuration) {
    const SECONDS_IN = {d: 86400, h: 3600, m: 60, s: 1};
    if (!precision) {
        precision = "s";
    }
    input = parseInt(input, 10);
    var language_cc = language;
    if (language_cc != null) {
        language_cc = language_cc.replace("-", "_");
        var fallbacks = [];
        var language = language_cc.substr(0, 2);
        switch (language) {
        case "zh":
            // Use zh_TW for zh_HK
            fallbacks.push("zh_TW");
            break
        }
        if (language != language_cc) {
            fallbacks.push(language);
        }
        // Fallback to english, if the language isn't found
        fallbacks.push("en");

        var units = ["d", "h", "m", "s"];
        switch (precision) {
            case "d":
                units.pop();
                // fallthrough
            case "h":
                units.pop();
                // fallthrough
            case "m":
                units.pop();
                // fallthrough
            case "s":
                break
            default:
                return "[Error: precision must be d, h, m or s, it's " + precision + "]";
        }

        try {
            // humanizeDuration accepts only milliseconds
            return humanize(input * 1000, {
                language: language_cc,
                maxDecimalPoints: 0,
                units: units,
                fallbacks: fallbacks
            });
        } catch(err) {
            console.log(err.message + ": language_cc=" + language_cc)
            // if we crash, fallthrough to english
        }
    }
    var result = "";
    for (var k in SECONDS_IN) {
        var t = (input / SECONDS_IN[k] | 0); // Math.floor

        if (t > 0) {
            if (!result) {
                result = t + k;
            } else {
                result += " " + t + k;
            }
        }

        if (precision == k) {
            return result ? result : "<1" + k;
        } else {
            input %= SECONDS_IN[k];
        }
    }
    return "[Error: incorrect usage, precision must be one of " + Object.keys(SECONDS_IN) + "]";
}

export function timestamp(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    const pad = value => String(value).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
        `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}
