import {test, expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

test('editor retains folder restrictions and ordered attribute rules', async ({page}, testInfo) => {
    let saved;
    await folderFixture(page, {folder:{blockIndexing:true}});
    await page.route('**/rest/config', async route => {
        if(route.request().method() === 'PUT'){saved=route.request().postDataJSON();return route.fulfill({status:200,body:''});}
        return route.fallback();
    });
    await page.goto('/');
    await page.getByRole('button',{name:/Folder under test/}).click();
    await page.locator('.dashboard-folders').getByRole('button',{name:/Edit/}).click();
    const dialog=page.getByRole('dialog',{name:'Edit Folder',exact:true});
    await dialog.getByRole('link',{name:'Advanced',exact:true}).click();
    const type=dialog.getByRole('combobox',{name:'Folder Type',exact:true});
    await expect(type.locator('option[value=receiveencrypted]')).toHaveCount(0);
    await type.selectOption('sendonly');
    await expect(dialog.getByRole('checkbox',{name:'Sync Ownership',exact:true})).toBeDisabled();
    await expect(dialog.getByRole('combobox',{name:'File Pull Order',exact:true})).toBeDisabled();
    await expect(dialog.getByRole('checkbox',{name:'Block Indexing',exact:true})).toBeChecked();
    await type.selectOption('sendreceive');
    await dialog.getByRole('checkbox',{name:'Sync Extended Attributes',exact:true}).check();
    await expect(dialog.getByRole('checkbox',{name:'Send Extended Attributes',exact:true})).toBeChecked();
    await expect(dialog.getByRole('checkbox',{name:'Send Extended Attributes',exact:true})).toBeDisabled();
    await dialog.getByRole('button',{name:'Add filter entry',exact:true}).click();
    await dialog.getByRole('textbox',{name:'Active filter rules 1',exact:true}).fill('*');
    await dialog.getByRole('checkbox',{name:'permit 1',exact:true}).check();
    await dialog.getByRole('button',{name:'Add filter entry',exact:true}).click();
    await dialog.getByRole('textbox',{name:'Active filter rules 1',exact:true}).fill('user.secret.*');
    await expect(dialog.getByRole('textbox',{name:'Active filter rules 2',exact:true})).toHaveValue('*');
    await page.screenshot({path:testInfo.outputPath('attribute-rules.png')});
    await dialog.getByRole('button',{name:/Save/}).click();
    await expect(dialog).toHaveCount(0);
    expect(saved.folders[0].xattrFilter.entries).toEqual([{match:'user.secret.*',permit:false},{match:'*',permit:true}]);
});

test('a new folder stays paused through ignore load/save failures and retries', async ({page}) => {
    await folderFixture(page);
    let config, ignoreReads=0, ignoreWrites=0; const operations=[];
    await page.route('**/rest/config', async route => {
        if(route.request().method()==='PUT'){
            config=route.request().postDataJSON();
            operations.push({type:'config',paused:config.folders.find(folder=>folder.id==='editor-new')?.paused});
            return route.fulfill({status:200,body:''});
        }
        const value=await (await route.fetch()).json();
        value.defaults.ignores.lines=['*.tmp','// default'];
        value.defaults.folder.path='/test/default';
        await route.fulfill({json:value});
    });
    await page.route('**/rest/system/browse?*',route=>route.fulfill({json:['/test/folder']}));
    await page.route('**/rest/db/ignores?*',async route=>{
        if(route.request().method()==='GET'){
            ignoreReads++; return ignoreReads===1 ? route.fulfill({status:500,body:'test ignore load failed'}) : route.fulfill({json:{ignore:[]}});
        }
        ignoreWrites++; operations.push({type:'ignores',lines:route.request().postDataJSON().ignore});
        return ignoreWrites===1 ? route.fulfill({status:500,body:'test ignore write failed'}) : route.fulfill({json:{ignore:route.request().postDataJSON().ignore}});
    });
    await page.goto('/');
    await page.getByRole('button',{name:/Add Folder/}).click();
    const dialog=page.getByRole('dialog',{name:'Add Folder',exact:true});
    await dialog.getByRole('link',{name:'Advanced',exact:true}).click();
    await dialog.getByRole('combobox',{name:'Folder Type',exact:true}).selectOption('receiveencrypted');
    await expect(dialog.getByRole('link',{name:'Ignore Patterns',exact:true})).toHaveAttribute('aria-disabled','true');
    await expect(dialog.getByRole('checkbox',{name:'Watch for Changes',exact:true})).toBeDisabled();
    await dialog.getByRole('combobox',{name:'Folder Type',exact:true}).selectOption('sendreceive');
    await dialog.getByRole('link',{name:'General',exact:true}).click();
    await dialog.getByRole('textbox',{name:'Folder ID',exact:true}).fill('editor-new');
    await dialog.getByRole('textbox',{name:'Folder Label',exact:true}).fill('New label');
    await expect(dialog.getByRole('combobox',{name:'Folder Path',exact:true})).toHaveValue(/New label$/);
    await dialog.getByRole('combobox',{name:'Folder Path',exact:true}).fill('/test/explicit');
    await dialog.getByRole('textbox',{name:'Folder Label',exact:true}).fill('Renamed label');
    await expect(dialog.getByRole('combobox',{name:'Folder Path',exact:true})).toHaveValue('/test/explicit');
    await dialog.getByRole('link',{name:'Ignore Patterns',exact:true}).click();
    const add=dialog.getByRole('checkbox',{name:'Add Ignore Patterns',exact:true});
    await expect(add).not.toBeChecked(); await add.check();
    const save=dialog.getByRole('button',{name:/Save/});
    await save.click();
    await expect(dialog).toContainText('test ignore load failed');
    await expect(save).toBeDisabled();
    expect(operations).toEqual([{type:'config',paused:true}]);
    await dialog.getByRole('button',{name:'Retry',exact:true}).click();
    await expect(dialog.getByRole('textbox',{name:'Ignore Patterns',exact:true})).toHaveValue('*.tmp\n// default');
    await save.click();
    await expect(dialog).toContainText('test ignore write failed');
    expect(operations.at(-1).type).toBe('ignores');
    expect(config.folders.find(folder=>folder.id==='editor-new').paused).toBe(true);
    await save.click();
    await expect(dialog).toHaveCount(0);
    expect(operations.at(-1)).toEqual({type:'config',paused:false});
    expect(ignoreWrites).toBe(2);
});

