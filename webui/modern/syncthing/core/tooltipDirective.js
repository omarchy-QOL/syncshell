angular.module('syncthing.core')
    .directive('tooltip', function () {
        return {
            restrict: 'A',
            link: function (scope, element, attributes) {
                var content = element.children('[tooltip-content]');
                var options = content.length ? {
                    html: true,
                    title: function () { return content.html(); }
                } : {};
                if (attributes.tooltipSelector) {
                    options.selector = attributes.tooltipSelector;
                    options.title = function () { return element.attr('data-original-title'); };
                }
                $(element).tooltip(options);
            }
        };
    });
