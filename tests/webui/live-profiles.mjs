import {chromium,expect} from '@playwright/test';
import {access,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
const root='/home/iz/Work/syncshell-framework-ports';
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
const rgb=hex=>'rgb('+[1,3,5].map(index=>parseInt(hex.slice(index,index+2),16)).join(', ')+')';
const background=file=>rgb(execFileSync('omarchy-theme-color',file?['--file',file,'background']:['background'],{encoding:'utf8'}).trim());
const results=[];
try{
 for(const[index,framework]of ['svelte','preact'].entries()){
  const runtime=join(root,'runtime',framework);await access(join(runtime,'.syncshell-port-fixture'));
  const prepare=join(root,'packages',framework,'hosts/omarchy/scripts/syncthing-theme.sh');
  const tokyo='/home/iz/.local/share/omarchy/themes/tokyo-night/colors.toml';
  const white='/home/iz/.local/share/omarchy/themes/white/colors.toml';
  execFileSync(prepare,['prepare','omarchy',join(runtime,'gui'),tokyo],{stdio:'ignore'});
  const page=await browser.newPage({viewport:{width:1908,height:954},colorScheme:'dark'});
  const failures=[];page.on('pageerror',error=>failures.push(error.message));
  await page.goto(`http://127.0.0.1:${18401+index}/`);
  for(const profile of ['syncshell-modern','syncthing-omarchy']){
   await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
   await page.getByRole('link',{name:/Actions/}).click();await page.getByRole('link',{name:'Settings',exact:true}).click();
   const settings=page.getByRole('dialog',{name:'Settings',exact:true});
   await settings.getByRole('link',{name:'GUI',exact:true}).click();
   const selector=settings.getByRole('combobox',{name:'GUI Theme',exact:true});
   const previous=await selector.inputValue();
   await selector.selectOption(profile);
   if(previous===profile) await settings.getByRole('button',{name:'Close',exact:true}).click();
   else await Promise.all([page.waitForEvent('domcontentloaded'),settings.getByRole('button',{name:'Save',exact:true}).click()]);
   await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
   expect(await page.evaluate(()=>typeof window.angular)).toBe('undefined');
   await page.locator('.dashboard-folders .panel-heading').click();
   await page.locator('.dashboard-remotes .panel-heading').first().click();
   await expect(page.locator('.folder-state-summary')).toBeVisible();
   await page.screenshot({path:join(root,framework+'-'+profile+'.png')});
  }
  await expect.poll(()=>page.locator('body').evaluate(el=>getComputedStyle(el).backgroundColor)).toBe(background(tokyo));
  await page.getByText('Folder information',{exact:true}).click();
  await page.evaluate(()=>{window.profileContinuity='retained';});
  let navigations=0;page.on('framenavigated',frame=>{if(frame===page.mainFrame())navigations++;});
  execFileSync(prepare,['prepare','omarchy',join(runtime,'gui'),white],{stdio:'ignore'});
  await page.bringToFront();
  await expect.poll(()=>page.locator('body').evaluate(el=>getComputedStyle(el).backgroundColor),{timeout:8000}).toBe(background(white));
  expect(await page.evaluate(()=>window.profileContinuity)).toBe('retained');
  expect(await page.getByText('Folder information',{exact:true}).evaluate(el=>el.parentElement.open)).toBe(true);
  expect(navigations).toBe(0);
  await page.screenshot({path:join(root,framework+'-omarchy-white-live.png')});
  execFileSync(prepare,['prepare','omarchy',join(runtime,'gui')],{stdio:'ignore'});
  await expect.poll(()=>page.locator('body').evaluate(el=>getComputedStyle(el).backgroundColor),{timeout:8000}).toBe(background());
  expect(navigations).toBe(0);expect(failures).toEqual([]);
  await page.screenshot({path:join(root,framework+'-omarchy-current.png')});
  results.push({framework,result:'passed',checks:['GUI theme selection reloads native profiles','no Angular runtime','live dark-to-light palette update','disclosure state preserved without reload','current Omarchy palette restored to test profile']});
  await page.close();
 }
 await writeFile(join(root,'profiles-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
}finally{await browser.close();}
