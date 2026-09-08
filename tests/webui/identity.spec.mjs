import {test, expect} from '@playwright/test';

test('identity previews retain encoded text and About retains attribution and paths', async ({page},testInfo)=>{
    const pathsResponse = page.waitForResponse(response =>
        new URL(response.url()).pathname === '/rest/system/paths' && response.ok());
    await page.goto('/');
    await expect(page.locator('.dashboard-folders .panel-heading')).toBeVisible();
    await page.getByRole('link',{name:/Actions/}).click();
    await page.getByRole('link',{name:'Show ID',exact:true}).click();
    const identity=page.getByRole('dialog');
    const id=await identity.locator('.text-monospace strong').textContent();
    await identity.getByRole('button',{name:'Share by Email',exact:true}).click();
    const email=page.getByRole('dialog',{name:'Share by Email',exact:true});
    const emailURL=new URL(await email.getByRole('link',{name:'Share',exact:true}).getAttribute('href'));
    expect(emailURL.protocol).toBe('mailto:');
    expect(emailURL.searchParams.get('body')).toContain('\r\n\r\n'+id+'\r\n\r\n');
    expect(emailURL.searchParams.get('subject')).not.toContain('{{');
    await page.screenshot({path:testInfo.outputPath('identity-email.png')});
    await email.getByRole('button',{name:'Cancel',exact:true}).click();
    await identity.getByRole('button',{name:'Share by SMS',exact:true}).click();
    const sms=page.getByRole('dialog',{name:'Share by SMS',exact:true});
    const smsURL=new URL(await sms.getByRole('link',{name:'Share',exact:true}).getAttribute('href'));
    expect(smsURL.protocol).toBe('sms:');
    expect(smsURL.searchParams.get('body')).toContain(id.replaceAll('-',''));
    await sms.getByRole('button',{name:'Cancel',exact:true}).click();
    await identity.getByRole('button',{name:/Close/}).click();
    await page.getByRole('link',{name:/Help/}).click();
    await page.getByRole('link',{name:'About',exact:true}).click();
    const about=page.getByRole('dialog',{name:'About',exact:true});
    await expect(about).toContainText('Jakob Borg');
    await about.getByRole('link',{name:'Included Software',exact:true}).click();
    await expect(about).not.toContainText('AngularJS');
    const license=await about.getByRole('link',{name:'MIT license',exact:true}).getAttribute('href');
    expect((await page.request.get(license)).status()).toBe(200);
    await about.getByRole('link',{name:'Paths',exact:true}).click();
    const paths = await (await pathsResponse).json();
    await expect(about).toContainText(paths['baseDir-userHome']);
    await page.screenshot({path:testInfo.outputPath('about-paths.png')});
});
