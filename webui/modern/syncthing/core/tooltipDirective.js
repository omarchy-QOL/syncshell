angular.module('syncthing.core')
    .directive('tooltip', function () {
        return {
            restrict: 'A',
            link: function (scope, element, attributes) {
                var content = element.children('[tooltip-content]');
                $(element).tooltip(content.length ? {
                    html: true,
                    title: function () { return content.html(); }
                } : {});
            }
        };
    });
