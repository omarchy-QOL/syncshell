angular.module('syncthing.core')
    .directive('stripeSections', function () {
        return {
            restrict: 'A',
            link: function (scope, element) {
                var root = element[0], frame;
                function paint() {
                    frame = null;
                    if (!root.getClientRects().length) return;
                    var index = 0;
                    root.querySelectorAll('details > summary, details > table > tbody > tr, .remote-status tr')
                        .forEach(function (row) {
                            var section = row.closest('details');
                            if (row.tagName !== 'SUMMARY' && section && !section.open) return;
                            if (!row.getClientRects().length || getComputedStyle(row).display === 'none') return;
                            row.classList.toggle('section-stripe', index++ % 2 === 1);
                        });
                }
                function schedule() {
                    if (!frame) frame = requestAnimationFrame(paint);
                }
                var observer = new MutationObserver(function (changes) {
                    if (changes.some(function (change) {
                        if (change.type === 'attributes') {
                            return change.attributeName !== 'class'
                                || (change.oldValue || '').split(/\s+/).includes('ng-hide')
                                || change.target.matches('.panel-collapse, .ng-hide, .visible-xs, .hidden-xs');
                        }
                        return Array.from(change.addedNodes).concat(Array.from(change.removedNodes))
                            .some(function (node) { return node.nodeType === 1; });
                    })) schedule();
                });
                observer.observe(root, {childList: true, subtree: true, attributes: true,
                    attributeFilter: ['open', 'hidden', 'class'], attributeOldValue: true});
                scope.$on('dashboardTabShown', schedule);
                root.addEventListener('toggle', schedule, true);
                window.addEventListener('resize', schedule);
                scope.$on('$destroy', function () {
                    observer.disconnect();
                    cancelAnimationFrame(frame);
                    root.removeEventListener('toggle', schedule, true);
                    window.removeEventListener('resize', schedule);
                });
                schedule();
            }
        };
    });
