import {chromium,expect} from '@playwright/test';
import {access,mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
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
  const identity=await mkdtemp(join(runtime,'new-device-'));
  execFileSync('/usr/bin/syncthing',['generate','--home',identity,'--no-port-probing'],{stdio:'ignore'});
  const xml=await readFile(join(identity,'config.xml'),'utf8');
  const id=xml.match(/<device\s+id="([A-Z2-7-]+)"/)[1];
  const page=await browser.newPage({viewport:{width:1500,height:954},colorScheme:'dark'});
  const failures=[];page.on('pageerror',error=>failures.push(error.message));
  await page.goto(`http://127.0.0.1:${18401+index}/`);await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
  const original=await api(page,'config');
  const label='Disposable untrusted peer',password='test-only & literal <password>';
  try{
   await page.getByRole('button',{name:'Add Remote Device',exact:true}).click();
   const editor=page.getByRole('dialog',{name:'Add Device',exact:true});
   await editor.getByRole('textbox',{name:'Device ID',exact:true}).fill(id);
   await editor.getByRole('textbox',{name:'Device Name',exact:true}).fill(label);
   await editor.getByRole('link',{name:'Advanced',exact:true}).click();
   await editor.getByRole('textbox',{name:'Addresses',exact:true}).fill('tcp://127.0.0.1:1');
   await editor.getByRole('checkbox',{name:'Introducer',exact:true}).check();
   await editor.getByRole('checkbox',{name:'Auto Accept',exact:true}).check();
   await editor.getByRole('checkbox',{name:'Untrusted',exact:true}).check();
   await expect(editor.getByRole('checkbox',{name:'Introducer',exact:true})).not.toBeChecked();
   await expect(editor.getByRole('checkbox',{name:'Auto Accept',exact:true})).toBeDisabled();
   await editor.getByRole('link',{name:'Sharing',exact:true}).click();
   const folder=original.folders.find(folder=>folder.id==='port-verification');
   await editor.getByRole('checkbox',{name:folder.label,exact:true}).check();
   await editor.getByLabel('Encryption Password: '+folder.label,{exact:true}).fill(password);
   await editor.getByRole('button',{name:/Save/}).click();await expect(editor).toHaveCount(0);
   const added=await api(page,'config');const device=added.devices.find(device=>device.deviceID===id);
   expect(device.untrusted).toBe(true);expect(device.introducer).toBe(false);expect(device.autoAcceptFolders).toBe(false);
   expect(added.folders.find(folder=>folder.id==='port-verification').devices.find(member=>member.deviceID===id).encryptionPassword).toBe(password);
   const heading=page.getByRole('button',{name:new RegExp(label)});await heading.click();
   const panel=page.locator('.dashboard-remotes .panel').filter({has:heading});await panel.getByRole('button',{name:/Edit/}).click();
   const edit=page.getByRole('dialog',{name:'Edit Device',exact:true});await edit.getByRole('button',{name:'Remove',exact:true}).click();
   const confirm=page.getByRole('dialog',{name:'Remove Device',exact:true});await confirm.getByRole('button',{name:'Yes',exact:true}).click();
   await expect(edit).toHaveCount(0);const removed=await api(page,'config');
   expect(removed.devices.some(device=>device.deviceID===id)).toBe(false);
   expect(removed.folders.some(folder=>folder.devices.some(member=>member.deviceID===id))).toBe(false);
   expect(failures).toEqual([]);
   results.push({framework,result:'passed',checks:['real new device validation and save','untrusted clears introducer/auto-accept','encryption password round trip','confirmed removal also clears folder membership']});
  }finally{await api(page,'config','PUT',original);await page.close();await rm(identity,{recursive:true,force:true});}
 }
 await writeFile(join(root,'device-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
}finally{await browser.close();}
