export function identityMessage(device, method, t) {
    const values = {devicename: device.name || device.deviceID.slice(0, 7)};
    const subject = t('Syncthing device ID for "{%devicename%}"', values);
    const footer = t('Learn more at {%url%}', {url: 'https://syncthing.net'});
    const body = method === 'email' ? [
        t('To connect with the Syncthing device named "{%devicename%}", add a new remote device on your end with this ID:', values),
        device.deviceID,
        t("Syncthing is a continuous file synchronization program. It synchronizes files between two or more computers in real time, safely protected from prying eyes. Your data is your data alone and you deserve to choose where it is stored, whether it is shared with some third party, and how it's transmitted over the internet."), footer,
    ].join('\r\n\r\n') : [subject, device.deviceID.replaceAll('-', ''), footer].join('\n');
    return {subject, body, href: method === 'email' ? 'mailto:?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body) : 'sms:?&body=' + encodeURIComponent(body)};
}
