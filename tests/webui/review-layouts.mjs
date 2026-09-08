import {chromium} from '@playwright/test';
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
const root='/home/iz/Work/syncshell-framework-ports';
const offline=process.argv.includes('--offline');
const output=join(root,offline?'layout-offline-evidence':'layout-evidence');await mkdir(output,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
const results=[];
try{
 for(const[index,framework]of ['svelte','preact'].entries()){
  const url=`http://127.0.0.1:${18401+index}/`;
  const seed=await browser.newPage();await seed.goto(url);await seed.locator('.dashboard-folders .panel-heading').waitFor();
  const data=await seed.evaluate(async()=>{
   const name='CSRF-Token-'+window.metadata.deviceIDShort;
   const cookie=document.cookie.split(';').map(value=>value.trim()).find(value=>value.startsWith(name+'='));
   const headers={['X-'+name]:decodeURIComponent(cookie.slice(name.length+1))};
   const read=path=>fetch('rest/'+path,{headers}).then(response=>response.json());
   return {config:await read('config'),system:await read('system/status'),stats:await read('stats/folder'),connections:await read('system/connections'),deviceStats:await read('stats/device'),langs:window.validLangs};
  });await seed.close();
  const folder=data.config.folders[0],id='P56IOI7-MZJNU2Y-IQGDREY-DM2MGTI-MGL3BXN-PQ6W5BM-TBBZ4TJ-XZWICQ2';
  data.config.devices.push({...data.config.devices[0],deviceID:id,name:'Offline peer',addresses:['tcp://192.0.2.1:22000']});
  folder.devices.push({deviceID:id});folder.label='Folder under test';
  folder.path='/test/a-long-directory-name/another-long-directory/important-syncthing-folder';
  data.system.lastDialStatus={'tcp://192.0.2.1:22000':{when:'2026-09-08T12:00:00Z',error:'dial tcp 192.0.2.1:22000: i/o timeout'}};
  data.stats[folder.id].lastFile={at:'2026-09-08T12:00:00Z',filename:'nested/a-long-filename-that-should-retain-its-ending-and-extension.txt',deleted:true};
  if(offline){data.connections.connections[id]={connected:false,inBytesTotal:0,outBytesTotal:0};data.deviceStats[id]={lastSeen:new Date(Date.now()-86400000).toISOString()};}
  const cases=offline?[{lang:'en',width:1908,scale:1},{lang:'de',width:390,scale:1},{lang:'ar',width:640,scale:1}]:[...data.langs.map(lang=>({lang,width:954,scale:1})),...['en','de','ar','zh-CN'].flatMap(lang=>[1908,640,390].map(width=>({lang,width,scale:1}))),...['en','de'].map(lang=>({lang,width:954,scale:2}))];
  const context=await browser.newContext({colorScheme:'dark'});
  for(const scenario of cases){
   const page=await context.newPage();await page.setViewportSize({width:scenario.width,height:954});
   if(scenario.scale!==1){const cdp=await context.newCDPSession(page);await cdp.send('Emulation.setDeviceMetricsOverride',{width:scenario.width,height:477,deviceScaleFactor:scenario.scale,mobile:false});}
   const errors=[];page.on('pageerror',error=>errors.push(error.message));
   await page.route('**/rest/config',route=>route.fulfill({json:data.config}));
   await page.route('**/rest/system/status',route=>route.fulfill({json:data.system}));
   if(offline){await page.route('**/rest/system/connections',route=>route.fulfill({json:data.connections}));await page.route('**/rest/stats/device',route=>route.fulfill({json:data.deviceStats}));}
   await page.route('**/rest/stats/folder',route=>route.fulfill({json:data.stats}));
   await page.route('**/rest/db/status?*',route=>route.fulfill({json:{state:'idle',errors:0,pullErrors:0,needTotalItems:1025,needBytes:2048,globalFiles:109274,localFiles:108249,globalDirectories:12921,localDirectories:12921,globalBytes:7351042089,localBytes:7351040041,receiveOnlyTotalItems:0}}));
   await page.route('**/rest/db/completion?*',route=>route.fulfill({json:{completion:50,needItems:1025,needDeletes:0,needBytes:2048,globalBytes:4096,remoteState:'valid'}}));
   await page.route('**/rest/events?*',route=>route.request().url().includes('limit=')?route.fulfill({json:[{id:1,type:'Starting',data:{}}]}):undefined);
   await page.goto(url+'?lang='+encodeURIComponent(scenario.lang));
   await page.locator('.dashboard-folders .panel-heading').click();
   for(const header of await page.locator('.dashboard-remotes .panel-heading').all())await header.click();
   await page.locator('.folder-state-summary').waitFor();
   await page.locator('details').evaluateAll(elements=>elements.forEach(element=>{element.open=true;}));
   const geometry=await page.evaluate(()=>({
    documentOverflow:document.documentElement.scrollWidth>innerWidth+2,
    buttons:[...document.querySelectorAll('button')].filter(element=>element.getClientRects().length && element.scrollWidth>element.clientWidth+2).map(element=>element.textContent.trim()),
    language:document.documentElement.lang,
   }));
   const result={framework,...scenario,...geometry,errors};results.push(result);
   if(geometry.documentOverflow || geometry.buttons.length || errors.length || (['en','de','ar','zh-CN'].includes(scenario.lang)&&scenario.width!==954))
    await page.screenshot({path:join(output,`${framework}-${scenario.lang}-${scenario.width}-${scenario.scale}.png`),fullPage:true});
   await page.close();
  }
  await context.close();console.log(framework+': '+cases.length+' layout/language cases inspected');
 }
 await writeFile(join(root,offline?'layout-offline-results.json':'layout-results.json'),JSON.stringify(results,null,2));
 console.log(JSON.stringify({cases:results.length,failures:results.filter(result=>result.documentOverflow||result.buttons.length||result.errors.length)}));
}finally{await browser.close();}
