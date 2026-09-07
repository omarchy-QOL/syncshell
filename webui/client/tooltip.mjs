let nextTooltip = 0;

export function bindTooltip(trigger, tip) {
    let timer;
    tip.id = 'syncshell-tooltip-' + ++nextTooltip;
    function position() {
        if (!tip.matches(':popover-open')) return;
        const rect = trigger.getBoundingClientRect();
        const bounds = tip.getBoundingClientRect();
        const above = rect.top > bounds.height + 8;
        tip.classList.toggle('top', above);
        tip.classList.toggle('bottom', !above);
        tip.style.top = (above ? rect.top - bounds.height - 5 : rect.bottom + 5) + 'px';
        tip.style.left = Math.max(8, Math.min(innerWidth - bounds.width - 8,
            rect.left + rect.width / 2 - bounds.width / 2)) + 'px';
    }
    function show() {
        clearTimeout(timer);
        timer = setTimeout(() => {
            tip.showPopover();
            trigger.setAttribute('aria-describedby', tip.id);
            position();
        }, 400);
    }
    function hide() {
        clearTimeout(timer);
        tip.hidePopover();
        trigger.removeAttribute('aria-describedby');
    }
    function key(event) { if (event.key === 'Escape') hide(); }
    trigger.addEventListener('mouseenter', show);
    trigger.addEventListener('mouseleave', hide);
    trigger.addEventListener('focus', show);
    trigger.addEventListener('blur', hide);
    trigger.addEventListener('keydown', key);
    window.addEventListener('resize', position);
    window.addEventListener('scroll', position, true);
    const observer = new MutationObserver(position);
    observer.observe(tip, {childList: true, characterData: true, subtree: true});
    return () => {
        clearTimeout(timer);
        observer.disconnect();
        trigger.removeEventListener('mouseenter', show);
        trigger.removeEventListener('mouseleave', hide);
        trigger.removeEventListener('focus', show);
        trigger.removeEventListener('blur', hide);
        trigger.removeEventListener('keydown', key);
        window.removeEventListener('resize', position);
        window.removeEventListener('scroll', position, true);
    };
}
