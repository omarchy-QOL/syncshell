import {test,expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

test('local changes show empty-file sizes and page through the API',async({page})=>{
 await folderFixture(page,{folder:{type:'receiveonly'},model:{receiveOnlyTotalItems:25,receiveOnlyChangedBytes:1}});
 const reads=[];
 await page.route('**/rest/db/localchanged?*',async route=>{
  const query=new URL(route.request().url()).searchParams;reads.push(Number(query.get('page')));
  await route.fulfill({json:{files:[{name:'empty.txt',size:0,type:'FILE_INFO_TYPE_FILE'},{name:'directory',size:128,type:'FILE_INFO_TYPE_DIRECTORY'}]}});
 });
 await page.goto('/');await page.getByRole('button',{name:/Folder under test/}).click();
 await page.locator('.dashboard-folders a[href="#local-changed"]').click();
 const dialog=page.getByRole('dialog',{name:'Locally Changed Items',exact:true});
 await expect(dialog.getByRole('columnheader',{name:'Path',exact:true})).toBeVisible();
 await expect(dialog.getByRole('row').filter({hasText:'empty.txt'})).toContainText('0 B');
 await expect(dialog.getByRole('row').filter({hasText:'directory'}).locator('td').last()).toHaveText('');
 await dialog.getByRole('link',{name:'2',exact:true}).click();
 await expect.poll(()=>reads).toEqual([1,2]);
});

test('remote needed details retain paths metadata and pagination',async({page})=>{
 await folderFixture(page);
 await page.route('**/rest/db/completion?*',route=>route.fulfill({json:{completion:50,needItems:25,needDeletes:0,needBytes:2048,globalBytes:4096,remoteState:'valid'}}));
 const reads=[];
 await page.route('**/rest/db/remoteneed?*',async route=>{
  const query=new URL(route.request().url()).searchParams;reads.push({page:Number(query.get('page')),folder:query.get('folder'),device:query.get('device')});
  await route.fulfill({json:{files:[{name:'nested/remote.txt',size:2048,type:'FILE_INFO_TYPE_FILE',modified:'2026-09-08T12:00:00Z',modifiedBy:''}]}});
 });
 await page.goto('/');await page.locator('.dashboard-remotes .panel-heading').first().click();
 await page.locator('.dashboard-remotes a[href="#remote-needed"]').click();
 const dialog=page.getByRole('dialog');
 await expect(dialog).toContainText('nested/remote.txt');await expect(dialog).toContainText('Unknown');
 await dialog.getByRole('link',{name:'2',exact:true}).click();
 await expect.poll(()=>reads.map(read=>read.page)).toEqual([1,2]);expect(reads[0].folder).toBe('port-verification');expect(reads[0].device).toBeTruthy();
});
