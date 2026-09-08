import {chromium,expect} from '@playwright/test';
import {access,mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
const root='/home/iz/Work/syncshell-framework-ports';
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
const results=[];
try{
 for(const[index,framework]of ['svelte','preact'].entries()){
  const runtime=join(root,'runtime',framework);await access(join(runtime,'.syncshell-port-fixture'));
  const directory=await mkdtemp(join(runtime,'files','host-actions-'));
  const copy='report.sync-conflict-20260908-120000-ABCDEFG.txt',canonical='report.txt';
  await writeFile(join(directory,copy),'first conflict contents\n');
  const page=await browser.newPage({viewport:{width:1908,height:954},colorScheme:'dark'});
  const failures=[];page.on('pageerror',error=>{failures.push(error.message);console.error(framework,error.stack);});
  try{
   await page.goto(`http://127.0.0.1:${18421+index}/`);
   await page.getByRole('tab',{name:'Resolve sync conflicts',exact:true}).click();
   const panel=page.locator('.conflict-review');const all=panel.getByRole('button',{name:'Recheck all files',exact:true});
   await expect(all).toBeEnabled();await all.click();
   const row=panel.locator('.review-row').filter({hasText:directory.split('/').at(-1)});
   await expect(row).toHaveCount(1);
   let response=page.waitForResponse(response=>response.url().endsWith('/review/open') && response.request().method()==='POST');
   await row.getByRole('button',{name:'Open folder',exact:true}).click();expect((await response).status()).toBe(200);
   response=page.waitForResponse(response=>response.url().endsWith('/review/open') && response.request().method()==='POST');
   await row.locator('.review-copies a.review-file').click();expect((await response).status()).toBe(200);
   const opened=(await readFile(join(runtime,'evidence/open-actions.jsonl'),'utf8')).trim().split('\n').map(JSON.parse).slice(-2);
   expect(opened[0].files).toEqual([directory]);expect(opened[1].files).toEqual([join(directory,copy)]);
   await row.getByRole('button',{name:'Autoresolve',exact:true}).click();
   const confirm=page.getByRole('dialog',{name:'Restore original name',exact:true});
   await expect(confirm).toContainText(directory+'/'+canonical);
   await writeFile(join(directory,copy),'changed after the review was opened\n');
   response=page.waitForResponse(response=>response.url().endsWith('/review/restore-name') && response.request().method()==='POST');
   await confirm.getByRole('button',{name:'Rename',exact:true}).click();expect((await response).status()).toBe(409);
   await expect(confirm).toContainText('changed after the list was loaded');
   await expect.poll(()=>access(join(directory,canonical)).then(()=>true,()=>false)).toBe(false);
   await confirm.getByRole('button',{name:'Cancel',exact:true}).click();
   await row.getByRole('button',{name:'Recheck files in folder',exact:true}).click();
   await expect(all).toBeEnabled();
   await row.getByRole('button',{name:'Autoresolve',exact:true}).click();
   await expect(confirm).toBeVisible();
   await page.screenshot({path:join(root,framework+'-rename-review.png')});
   await confirm.getByRole('button',{name:'Rename',exact:true}).click();
   await expect(confirm).toHaveCount(0);
   await expect(row).toHaveCount(0);
   expect(await readFile(join(directory,canonical),'utf8')).toBe('changed after the review was opened\n');
   await rm(join(directory,canonical));await writeFile(join(directory,copy),'another conflict\n');
   await all.click();await expect(row).toHaveCount(1);
   await row.getByRole('button',{name:'Autoresolve',exact:true}).click();
   await writeFile(join(directory,canonical),'must not be overwritten\n');
   response=page.waitForResponse(response=>response.url().endsWith('/review/restore-name') && response.request().method()==='POST');
   await confirm.getByRole('button',{name:'Rename',exact:true}).click();expect((await response).status()).toBe(409);
   expect(await readFile(join(directory,canonical),'utf8')).toBe('must not be overwritten\n');
   await confirm.getByRole('button',{name:'Cancel',exact:true}).click();
   expect(failures).toEqual([]);
   results.push({framework,result:'passed',checks:['file-manager folder and file reveal accepted','stale review refused','confirmed rename restores canonical path','existing target retained','resolved row removed']});
  }finally{
   await rm(directory,{recursive:true,force:true});
   await page.evaluate(async()=>{
    const name='CSRF-Token-'+window.metadata.deviceIDShort;
    const token=document.cookie.split(';').map(part=>part.trim()).find(part=>part.startsWith(name+'='));
    await fetch('rest/db/scan?folder=port-verification',{method:'POST',headers:{['X-'+name]:decodeURIComponent(token.slice(name.length+1))}});
   });
   await page.close();
  }
 }
 await writeFile(join(root,'conflict-actions-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
}finally{await browser.close();}
