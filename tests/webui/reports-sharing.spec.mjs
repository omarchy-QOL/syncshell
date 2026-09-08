import {test,expect} from '@playwright/test';
import {folderFixture} from './folder-fixture.mjs';

async function configFixture(page,edit){
 let config;
 await page.route('**/rest/config',async route=>{
  if(route.request().method()==='PUT'){config=route.request().postDataJSON();return route.fulfill({status:200,body:''});}
  config ||= await edit(await (await route.fetch()).json(), route);
  await route.fulfill({json:config});
 });
 return ()=>config;
}
async function events(page){
 let pending,id=2;
 await page.route('**/rest/events?*',async route=>{
  if(route.request().url().includes('limit='))return route.fulfill({json:[{id:1,type:'Starting',data:{}}]});
  pending=route;
 });
 return async(type,data)=>{await expect.poll(()=>!!pending).toBe(true);const route=pending;pending=null;await route.fulfill({json:[{id:id++,type,data}]});};
}
for(const [accepted,answer,result]of [[0,'No',-1],[2,'No',2],[0,'Yes',4]])test(`usage consent ${accepted} ${answer} preserves the original decision`,async({page})=>{
 await folderFixture(page);
 const config=await configFixture(page,value=>{value.options.urAccepted=accepted;value.options.urSeen=0;return value;});
 await page.route('**/rest/system/status',async route=>route.fulfill({json:{...await(await route.fetch()).json(),urVersionMax:4}}));
 await page.route('**/rest/svc/report?*',route=>route.fulfill({json:{sample:'report preview'}}));
 await page.goto('/');
 const consent=page.getByRole('dialog',{name:'Allow Anonymous Usage Reporting?',exact:true});
 await expect(consent).toBeVisible();
 await consent.getByRole('button',{name:'Preview Usage Report',exact:true}).click();
 await expect(consent).toContainText('report preview');
 await consent.getByRole('button',{name:answer,exact:true}).click();
 await expect(consent).toHaveCount(0);
 expect(config().options.urAccepted).toBe(result);expect(config().options.urSeen).toBe(4);
});

test('report versions/difference and major upgrade warning retain their contracts',async({page},testInfo)=>{
 await folderFixture(page);
 await page.route('**/rest/system/status',async route=>route.fulfill({json:{...await(await route.fetch()).json(),urVersionMax:4}}));
 await page.route('**/rest/svc/report?*',async route=>{
  const version=Number(new URL(route.request().url()).searchParams.get('version'));
  await route.fulfill({json:version===2?{common:2}:{common:version,['added'+version]:true}});
 });
 await page.route('**/rest/system/upgrade',route=>route.fulfill({json:{newer:false,majorNewer:true,latest:'v3.0.0'}}));
 await page.goto('/');await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
 await page.getByRole('link',{name:/Actions/}).click();await page.getByRole('link',{name:'Settings',exact:true}).click();
 await page.getByRole('dialog',{name:'Settings',exact:true}).getByRole('button',{name:'Preview',exact:true}).click();
 const report=page.getByRole('dialog',{name:'Anonymous Usage Reporting',exact:true});
 await report.getByRole('combobox',{name:'Version',exact:true}).selectOption('3');
 await expect(report.locator('pre')).toContainText('added3');
 await report.getByRole('checkbox',{name:'Show diff with previous version',exact:true}).check();
 await expect(report.locator('pre')).not.toContainText('common');
 await page.screenshot({path:testInfo.outputPath('usage-difference.png')});
 await report.getByRole('button',{name:'Close',exact:true}).click();
 await page.getByRole('dialog',{name:'Settings',exact:true}).getByRole('button',{name:'Close',exact:true}).click();
 await page.getByRole('link',{name:/Actions/}).click();await page.getByRole('link',{name:'Upgrade v3.0.0',exact:true}).click();
 await expect(page.getByRole('dialog',{name:'Major Upgrade',exact:true})).toContainText('may not be compatible');
});

test('pending encrypted sharing opens the editor and preserves a password across toggles',async({page},testInfo)=>{
 await folderFixture(page);let peer;
 const config=await configFixture(page,async(value,route)=>{
  const status=await(await route.fetch({url:new URL('system/status',route.request().url().replace(/config$/, '')).href})).json();
  peer=value.devices.find(device=>device.deviceID!==status.myID);
  value.folders[0].devices=value.folders[0].devices.filter(member=>member.deviceID===status.myID);return value;
 });
 await page.route('**/rest/cluster/pending/folders',async route=>{
  await expect.poll(()=>!!peer).toBe(true);
  await route.fulfill({json:{'port-verification':{offeredBy:{[peer.deviceID]:{label:'Encrypted offer',remoteEncrypted:true,receiveEncrypted:false,time:'2026-09-08T12:00:00Z'}}}}});
 });
 await page.goto('/');await page.getByRole('tab',{name:/Notifications/}).click();
 await page.locator('.notifications').getByRole('button',{name:/Share/,exact:false}).click();
 const dialog=page.getByRole('dialog',{name:'Edit Folder',exact:true});
 const input=dialog.getByLabel('Encryption Password: '+peer.name,{exact:true});
 await expect(input).toHaveAttribute('required','');
 const before=JSON.stringify(config().folders[0]);
 await dialog.getByRole('button',{name:/Save/}).click();
 expect(JSON.stringify(config().folders[0])).toBe(before);
 const secret='test only & <literal> " password';
 await input.fill(secret);
 const selected=dialog.getByRole('checkbox',{name:peer.name,exact:true});
 await selected.uncheck();await selected.check();await expect(input).toHaveValue(secret);
 await dialog.getByRole('button',{name:'Show password',exact:true}).click();await expect(input).toHaveAttribute('type','text');
 await dialog.getByRole('button',{name:'Hide password',exact:true}).click();
 await page.screenshot({path:testInfo.outputPath('encrypted-share.png')});
 await dialog.getByRole('button',{name:/Save/}).click();await expect(dialog).toHaveCount(0);
 expect(config().folders[0].devices.find(member=>member.deviceID===peer.deviceID).encryptionPassword).toBe(secret);
});

test('notification severity changes from danger through warning and success to empty',async({page},testInfo)=>{
 await folderFixture(page);const push=await events(page);
 const config=await configFixture(page,value=>{value.gui.user='';value.gui.password='';value.gui.insecureAdminAccess=false;value.options.unackedNotificationIDs=['crAutoDisabled'];return value;});
 await page.route('**/rest/system/status',async route=>route.fulfill({json:{...await(await route.fetch()).json(),guiAddressUsed:'0.0.0.0:8384'}}));
 await page.route('**/rest/system/error',route=>route.fulfill({json:{errors:[{when:'2026-09-08T12:00:00Z',message:'Temporary test notice'}]}}));
 await page.route('**/rest/system/error/clear',route=>route.fulfill({status:200,body:''}));
 await page.goto('/');await page.getByRole('tab',{name:/Notifications/}).click();
 const indicator=page.locator('.notification-indicator');
 await expect(indicator.locator('.text-danger')).toBeVisible();
 await expect(indicator.locator('.text-warning')).toBeHidden();await expect(indicator.locator('.text-success')).toBeHidden();
 config().gui.insecureAdminAccess=true;await push('ConfigSaved',config());
 await expect(indicator.locator('.text-warning')).toBeVisible();
 const notice=page.locator('.notifications .panel').filter({hasText:'Temporary test notice'});
 await notice.getByRole('button',{name:/OK/}).click();
 await expect(indicator.locator('.text-success')).toBeVisible();
 await page.screenshot({path:testInfo.outputPath('remaining-notification.png')});
 await page.locator('.notifications .panel').getByRole('button',{name:/OK/}).click();
 await expect(indicator).toBeHidden();
 await expect(page.locator('.notifications')).toContainText('No pending notifications.');
 config().options.unackedNotificationIDs=['crAutoDisabled'];await push('ConfigSaved',config());
 await expect(indicator.locator('.text-success')).toBeVisible();
});
