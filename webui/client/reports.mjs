export function needsUsageConsent(state) {
    const options = state.config.options || {}, maximum = state.system.urVersionMax;
    return state.ready && options.urAccepted > -1 && options.urSeen < maximum && options.urAccepted < maximum;
}
export async function usageReport(api, version, diff, signal) {
    const report = await api.get('svc/report', {version}, signal);
    if (!diff || version <= 2) return report;
    const previous = await api.get('svc/report', {version: version - 1}, signal);
    return Object.fromEntries(Object.entries(report).filter(([key]) => !Object.hasOwn(previous, key)));
}
export function decideUsage(session, maximum, accepted) {
    return session.changeConfig(config => {
        if (accepted) config.options.urAccepted = maximum;
        else if (config.options.urAccepted === 0) config.options.urAccepted = -1;
        config.options.urSeen = maximum;
    });
}
