import {Tooltip} from './Tooltip.jsx';
export function ShareStatus({encrypted = false, remoteState = ''}) {
    return <>
        {encrypted && <Tooltip icon="fas fa-lock" label="Encrypted" text="Encrypted" />}
        {remoteState === 'paused' && <Tooltip icon="fas fa-pause" label="Paused" text="The remote device has paused this folder." />}
        {remoteState === 'notSharing' && <Tooltip icon="fas fa-exclamation-triangle" label="Not shared" text="The remote device has not accepted sharing this folder." />}
    </>;
}
