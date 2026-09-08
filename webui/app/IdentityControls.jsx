import {useContext, useState} from 'preact/hooks';
import {LocaleContext} from './locale-context.jsx';
import {Dialog} from './Dialog.jsx';
import {identityMessage} from '../client/identity.mjs';
export function IdentityControls({device, api}) {
    const {t} = useContext(LocaleContext);
    const [method, setMethod] = useState(''), [validated, setValidated] = useState(null);
    const [copied, setCopied] = useState(false), [error, setError] = useState('');
    const message = validated ? identityMessage(validated, method, t) : null;
    async function use(action) {
        setError('');
        try {
            const result = await api.get('svc/deviceid', {id: device.deviceID});
            if (result.error) throw new Error(result.error);
            const value = {...device, deviceID: result.id}; setValidated(value);
            if (action === 'copy') { await navigator.clipboard.writeText(value.deviceID); setCopied(true); }
            else setMethod(action);
        } catch (value) { setError(value.message); }
    }
    async function copy(text) { try { await navigator.clipboard.writeText(text); } catch (value) { setError(value.message); } }
    return <>
        <div class="folder-actions">
            <button type="button" class="btn btn-default" disabled={!device.deviceID} onClick={() => use('copy')}><span aria-hidden="true" class="fa fa-clone" /> {t(copied ? 'Copied!' : 'Copy')}</button>
            <button type="button" class="btn btn-default" disabled={!device.deviceID} onClick={() => use('email')}><span aria-hidden="true" class="fa fa-envelope-o" /> {t('Share by Email')}</button>
            <button type="button" class="btn btn-default" disabled={!device.deviceID} onClick={() => use('sms')}><span aria-hidden="true" class="fa fa-comments-o" /> {t('Share by SMS')}</button>
        </div>
        {error && <p class="text-danger" role="alert">{error}</p>}
        {method && message && <Dialog title={method === 'email' ? 'Share by Email' : 'Share by SMS'} large={method === 'email'} icon={method === 'email' ? 'fa fa-envelope-o' : 'fa fa-comments-o'} onClose={() => setMethod('')} footer={<>
            <a class="btn btn-primary" href={message.href}>{t('Share')}</a><button class="btn btn-default" onClick={() => setMethod('')}>{t('Cancel')}</button>
        </>}>
            <p>{t('The following text will automatically be inserted into a new message.')} {t(method === 'email' ? 'Your email app should open to let you choose the recipient and send it from your own address.' : 'Your SMS app should open to let you choose the recipient and send it from your own number.')} {t('You can also copy and paste the text into a new message manually.')}</p>
            {method === 'email' && <><h5>{t('Subject:')}</h5><pre class="port-share-text">{message.subject}</pre><button class="btn btn-default btn-sm" onClick={() => copy(message.subject)}>{t('Copy')}</button><h5>{t('Body:')}</h5></>}
            <pre class="port-share-text">{message.body}</pre><button class="btn btn-default btn-sm" onClick={() => copy(message.body)}>{t('Copy')}</button>
        </Dialog>}
    </>;
}
