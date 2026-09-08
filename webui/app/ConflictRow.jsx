import { useContext } from 'preact/hooks';
import { LocaleContext } from './locale-context.jsx';
import { parentPath, missingHelp } from '../client/conflicts.mjs';
import { unitPrefixed, timestamp } from '../client/format.mjs';
import { Tooltip } from './Tooltip.jsx';

export function ConflictRow({
    group,
    selected,
    permission,
    showAccessReason,
    loading,
    scanning,
    onSelect,
    onOpen,
    onRename,
    onRecheck
}) {
    const { t } = useContext(LocaleContext);
    const file = group.copies.find((copy) => copy.path === selected) || group.copies[0];
    const fileAccess = permission(group, file);
    const folderAccess = permission(group, group.current || file);
    function fileLink(group, file) {
        if (!file)
            return (
                <span class="text-warning">
                    <Tooltip
                        icon="fas fa-exclamation-triangle"
                        label="Missing current file"
                        text={t(missingHelp)}
                    />{' '}
                    {t('Missing current file')}
                </span>
            );
        if (!file.available)
            return (
                <span class="text-warning" title={t('Waiting for Syncthing to download this file')}>
                    {file.name} · {t('Not available locally')}
                </span>
            );
        const contents = (
            <>
                <span aria-hidden="true" class="fas fa-fw fa-file" />
                <span class="review-filename">{file.name}</span>
            </>
        );
        return permission(group, file).open ? (
            <a
                class="review-file"
                href="#open-file"
                title={group.root + '/' + file.path}
                onClick={(event) => {
                    event.preventDefault();
                    onOpen(group, file);
                }}
            >
                {contents}
            </a>
        ) : (
            <span class="review-file" title={group.root + '/' + file.path}>
                {contents}
            </span>
        );
    }
    const metadata = (file) => (
        <>
            {unitPrefixed(file.bytes, true)}B · {timestamp(file.modified)}
        </>
    );
    return (
        <tr key={group.id} class="review-row">
            <td class="review-context">
                <span class="review-path" title={group.root + '/' + parentPath(group.path)}>
                    {group.folderName}
                    {parentPath(group.path) ? ' / ' + parentPath(group.path) : ''}
                </span>
            </td>
            <td class="review-current">
                <span class="review-cell-label">{t('Current file')}</span>
                {fileLink(group, group.current)}
                {group.current ? (
                    <small class="review-file-meta">{metadata(group.current)}</small>
                ) : (
                    <small class="review-file-meta review-missing-hint">
                        {t('To keep a conflict file, rename it to:')}{' '}
                        <span class="review-filename" title={group.root + '/' + group.path}>
                            {group.name}
                        </span>
                    </small>
                )}
            </td>
            <td class="review-copies">
                {group.copies.length > 1 ? (
                    <select
                        class="form-control input-sm review-version"
                        aria-label={t('Conflict files') + ': ' + group.name}
                        value={file.path}
                        title={file.name}
                        onChange={(event) => onSelect(event.currentTarget.value)}
                    >
                        {group.copies.map((copy, index) => (
                            <option key={copy.path} value={copy.path}>
                                {index + 1}/{group.copies.length} · {copy.name}
                            </option>
                        ))}
                    </select>
                ) : (
                    <span class="review-mobile-label">{t('Conflict files')}</span>
                )}
                {fileLink(group, file)}
                <small class="review-file-meta review-conflict-meta">
                    {metadata(file)}
                    {!group.current && file.available && (
                        <button
                            class="btn btn-default review-autoresolve"
                            disabled={!fileAccess.rename || loading}
                            title={t(fileAccess.reason || '')}
                            onClick={() => onRename(file)}
                        >
                            <span class="text-warning">{t('Autoresolve')}</span>
                        </button>
                    )}
                </small>
                {showAccessReason && fileAccess.reason && (
                    <small class="text-warning">{t(fileAccess.reason)}</small>
                )}
            </td>
            <td class="review-actions">
                <button
                    class="btn btn-default"
                    disabled={!folderAccess.open || loading}
                    title={t(folderAccess.reason || '')}
                    onClick={() => onOpen(group)}
                >
                    <span aria-hidden="true" class="fas fa-folder-open" /> {t('Open folder')}
                </button>
                <button
                    class="btn btn-default"
                    disabled={loading}
                    aria-busy={scanning === group.id}
                    onClick={onRecheck}
                >
                    <span class={scanning === group.id ? 'text-warning review-rechecking' : ''}>
                        <span
                            aria-hidden="true"
                            class={`fas fa-refresh${scanning === group.id ? ' fa-spin' : ''}`}
                        />{' '}
                        {t('Recheck files in folder')}
                    </span>
                </button>
            </td>
        </tr>
    );
}
