import {chromium,expect} from '@playwright/test';
import {access,mkdtemp,mkdir,readFile,writeFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
const root='/home/iz/Work/syncshell-framework-ports';
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
async function api(page,path,method='GET',body){
 return page.evaluate(async({path,method,body})=>{
  const name='CSRF-Token-'+window.metadata.deviceIDShort;
  const token=document.cookie.split(';').map(part=>part.trim()).find(part=>part.startsWith(name+'='));
  const response=await fetch('rest/'+path,{method,headers:{['X-'+name]:decodeURIComponent(token.slice(name.length+1)),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
  if(!response.ok)throw Error(await response.text());
  const text=await response.text();return text?JSON.parse(text):null;
 },{path,method,body});
}
const results=[];
try{
 for(const[index,framework]of ['svelte','preact'].entries()){
  const runtime=join(root,'runtime',framework);await access(join(runtime,'.syncshell-port-fixture'));
  const directory=await mkdtemp(join(runtime,'ignore-flow-'));
  const page=await browser.newPage({viewport:{width:1500,height:954},colorScheme:'dark'});
  const failures=[];page.on('pageerror',error=>failures.push(error.message));
  await page.goto(`http://127.0.0.1:${18401+index}/`);
  await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
  const original=await api(page,'config');
  const defaults=['*.tmp','// live default'];
  try{
   await api(page,'config/defaults/ignores','PUT',{lines:defaults});
   await page.reload();await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
   for(const operation of ['save','cancel']){
    const id='ignore-flow-'+operation,path=join(directory,operation);await mkdir(path);
    await page.getByRole('button',{name:/Add Folder/}).click();
    const dialog=page.getByRole('dialog',{name:'Add Folder',exact:true});
    await dialog.getByRole('textbox',{name:'Folder ID',exact:true}).fill(id);
    await dialog.getByRole('combobox',{name:'Folder Path',exact:true}).fill(path);
    await dialog.getByRole('link',{name:'Ignore Patterns',exact:true}).click();
    await dialog.getByRole('checkbox',{name:'Add Ignore Patterns',exact:true}).check();
    await dialog.getByRole('button',{name:/Save/}).click();
    const patterns=dialog.getByRole('textbox',{name:'Ignore Patterns',exact:true});
    await expect(patterns).toHaveValue(defaults.join('\n'));
    expect((await api(page,'config/folders/'+id)).paused).toBe(true);
    await patterns.fill('*.cache\n// edited rules');
    await dialog.getByRole('button',{name:operation==='save'?/Save/:/Cancel/}).click();
    await expect(dialog).toHaveCount(0);
    expect((await api(page,'config/folders/'+id)).paused).toBe(false);
    const text=await readFile(join(path,'.stignore'),'utf8');
    expect(text.trim()).toBe(operation==='save'?'*.cache\n// edited rules':defaults.join('\n'));
   }
   expect(failures).toEqual([]);
   results.push({framework,result:'passed',checks:['new folder saved paused','default ignores loaded','save writes edited patterns before resume','cancel writes default patterns before resume']});
  }finally{
   await api(page,'config','PUT',original);await rm(directory,{recursive:true,force:true});await page.close();
  }
 }
 await writeFile(join(root,'ignores-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
}finally{await browser.close();}
