// Copyright (C) 2014 The Syncthing Authors.
// SPDX-License-Identifier: MPL-2.0

export function stripeSections(root) {
    let frame;
    function paint() {
        frame = undefined;
        if (!root.getClientRects().length) return;
        let index = 0;
        root.querySelectorAll('details > summary, details > table > tbody > tr, .remote-status tr')
            .forEach(row => {
                const section = row.closest('details');
                if (row.tagName !== 'SUMMARY' && section && !section.open) return;
                if (!row.getClientRects().length || getComputedStyle(row).display === 'none') return;
                row.classList.toggle('section-stripe', index++ % 2 === 1);
            });
    }
    function schedule() {
        if (!frame) frame = requestAnimationFrame(paint);
    }
    const observer = new MutationObserver(schedule);
    observer.observe(root, {childList: true, subtree: true, attributes: true,
        attributeFilter: ['open', 'hidden']});
    const resize = new ResizeObserver(schedule);
    resize.observe(root);
    root.addEventListener('toggle', schedule, true);
    schedule();
    return () => {
        observer.disconnect();
        resize.disconnect();
        cancelAnimationFrame(frame);
        root.removeEventListener('toggle', schedule, true);
    };
}
