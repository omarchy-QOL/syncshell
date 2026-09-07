angular.module('syncthing.core')
    .filter('compactNumber', function () {
        return function (input) {
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
        };
    });
