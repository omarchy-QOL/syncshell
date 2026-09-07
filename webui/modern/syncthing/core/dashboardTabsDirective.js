angular.module('syncthing.core')
    .directive('dashboardTabs', function () {
        return {
            restrict: 'A',
            link: function (scope, element) {
                var tabs = element.find('.dashboard-tabs [role="tab"]');
                function selected(event) {
                    tabs.each(function () {
                        var active = this === event.target;
                        $(this).attr({'aria-selected': active, tabindex: active ? 0 : -1});
                    });
                    scope.$broadcast('dashboardTabShown');
                }
                function keydown(event) {
                    var index = tabs.index(event.currentTarget);
                    switch (event.key) {
                    case 'ArrowRight': index = (index + 1) % tabs.length; break;
                    case 'ArrowLeft': index = (index + tabs.length - 1) % tabs.length; break;
                    case 'Home': index = 0; break;
                    case 'End': index = tabs.length - 1; break;
                    case ' ': break;
                    default: return;
                    }
                    event.preventDefault();
                    tabs.eq(index).tab('show').trigger('focus');
                }
                tabs.on('shown.bs.tab', selected).on('keydown', keydown);
                scope.$on('$destroy', function () {
                    tabs.off('shown.bs.tab', selected).off('keydown', keydown);
                });
            }
        };
    });
