import {connect,waitFor} from './browser.mjs';
import {writeFile,mkdir} from 'node:fs/promises';
const root='/home/iz/Work/syncshell-framework-ports',debug='http://127.0.0.1:19222';
const open=async url=>{const target=await fetch(debug+'/json/new?'+encodeURIComponent(url),{method:'PUT'}).then(response=>response.json());const page=await connect(target);await page.call('Runtime.enable');await page.call('Page.enable');return {target,page};};
const settings=await open('chrome://settings/appearance');
const find=`(()=>{const queue=[document];for(const root of queue)for(const node of root.querySelectorAll('*')){if(node.shadowRoot)queue.push(node.shadowRoot);if(node.tagName==='SELECT'&&node.id==='zoomLevel')return node;}return null;})()`;
const pages=[],results=[];let initial;
await mkdir(root+'/native-zoom-evidence',{recursive:true});
try{
 await waitFor(settings.page,find+' !== null','Chrome zoom setting');
 initial=await settings.page.evaluate(find+'.value');
 for(const[index,framework]of ['svelte','preact'].entries()){
  const item=await open(`http://127.0.0.1:${18401+index}/`);pages.push({...item,framework});
  await waitFor(item.page,"document.querySelector('.dashboard-folders .panel-heading') !== null",framework+' ready');
  await item.page.evaluate("document.querySelector('.dashboard-folders .panel-heading').click();document.querySelector('.dashboard-remotes .panel-heading').click();");
 }
 for(const value of ['0.5','0.6666666666666666','0.8','1','1.25','1.5','2']){
  await settings.page.evaluate(`(()=>{const select=${find};select.value=${JSON.stringify(value)};select.dispatchEvent(new Event('change',{bubbles:true,composed:true}));})()`);
  for(const {page,framework}of pages){
   await page.call('Page.bringToFront');
   await waitFor(page,`Math.abs(devicePixelRatio-${Number(value)}) < 0.02`,framework+' real zoom '+value);
   const geometry=await page.evaluate('({width:innerWidth,height:innerHeight,ratio:devicePixelRatio,overflow:document.documentElement.scrollWidth>innerWidth+2})');
   results.push({framework,zoom:Number(value),...geometry});
   if(['0.5','1','2'].includes(value)){
    const shot=await page.call('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    await writeFile(root+'/native-zoom-evidence/'+framework+'-'+value+'.png',Buffer.from(shot.data,'base64'));
   }
  }
 }
 await writeFile(root+'/native-zoom-results.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results));
}finally{
 if(initial!==undefined)await settings.page.evaluate(`(()=>{const select=${find};select.value=${JSON.stringify(initial)};select.dispatchEvent(new Event('change',{bubbles:true,composed:true}));})()`);
 for(const {page,target}of pages){page.close();await fetch(debug+'/json/close/'+target.id);}
 settings.page.close();await fetch(debug+'/json/close/'+settings.target.id);
}
