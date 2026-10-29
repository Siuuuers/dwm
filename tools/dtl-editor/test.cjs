const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const sandbox = {module: {exports: {}}};
vm.runInNewContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], sandbox);
const DTL = sandbox.module.exports;
const dayPath = path.resolve(__dirname, '../../dialogic/timelines/authored_week/Day1.dtl');
const original = fs.readFileSync(dayPath, 'utf8');
assert.equal(DTL.reconcile(original, DTL.normalize(original)), original);
const mixed = '# comment\r\nlabel 開始 (Display)\r\n未知 command\n\\Caption. #id:c\r\n# self-talk\r\n\\Thought. #id:t';
assert.equal(DTL.reconcile(mixed, DTL.normalize(mixed)), mixed);
assert.equal(DTL.reconcile(mixed, DTL.normalize(mixed).replace('Caption', 'Changed')), mixed.replace('Caption', 'Changed'));
assert.equal(DTL.reconcile('a\rb', 'a\nx\nb'), 'a\rx\rb');
const pair = 'label room\n# art background picture3\n\\Caption. #id:c\n# self-talk\n\\Thought. #id:t\nreturn';
for (const selection of ['\\Caption', '# self-talk', '\\Thought']) {
 const edit = DTL.insertion(pair, pair.indexOf(selection), '# checkpoint room.arrival');
 assert.equal(edit.text, pair.replace('\\Caption', '# checkpoint room.arrival\n\\Caption'));
}
assert.equal(DTL.insertion(pair,pair.indexOf('\\Caption'),'label arrival').text, pair.replace('# art', 'label arrival\n# art'));
assert.throws(() => DTL.insertion(pair,pair.indexOf('return'),'# checkpoint end'), /caption/);
const expected = [
 ['label','room.arrival','','','label room.arrival'],
 ['scene','draft.reading.early','','','# art scene draft.reading.early'],
 ['background','picture3','','','# art background picture3'],
 ['show','portrait_neutral','portrait','','# art show portrait_neutral slot=portrait'],
 ['hide','portrait','','','# art hide portrait'],
 ['music','quiet_room','','0.4','# audio music quiet_room fade=0.4'],
 ['stop','','','0','# audio music stop fade=0'],
 ['sfx','door_knock','','','# audio sfx door_knock'],
 ['checkpoint','room.arrival','','','# checkpoint room.arrival']
];
for (const [kind,id,slot,fade,result] of expected) {
 assert.equal(DTL.command(kind,id,slot,fade), result);
 assert.equal(DTL.issues(result).length,0,result);
}
for (const args of [['label','','',''],['show','portrait','',''],['music','quiet_room','','-1'],['sfx','stop','','']]) assert.throws(() => DTL.command(...args));
assert.equal(DTL.issues('label same\nlabel same').length,1);
assert.equal(DTL.issues('# audio music a fade=\n# art show x\n# checkpoint').length,3);
assert.equal(DTL.issues(original).length,0);
console.log('PASS: source preservation, caption-pair insertion, all nine controls and local feedback.');

async function browserJourney() {
 const {chromium} = require('playwright');
 const browser = await chromium.launch({headless:true});
 const page = await browser.newPage({viewport:{width:1280,height:900}});
 const errors=[]; page.on('pageerror',error=>errors.push(error.message));
 await page.goto('file://' + path.join(__dirname,'index.html'));
 async function load(name,buffer) { await page.locator('#file').setInputFiles({name,mimeType:'text/plain',buffer}); await page.waitForFunction(()=>!document.getElementById('source').disabled); }
 async function exported() {
  const pending = page.waitForEvent('download'); await page.getByRole('button',{name:'Export DTL',exact:true}).click();
  const download = await pending; return fs.readFileSync(await download.path());
 }
 async function select(text) {
  await page.locator('#source').evaluate((node,text)=>{node.focus();const pos=node.value.indexOf(text);node.setSelectionRange(pos,pos);node.dispatchEvent(new Event('select'));},text);
 }
 async function insert(kind,id,at,slot='',fade='') {
  await select(at); await page.locator('#kind').selectOption(kind);
  if (kind!=='stop') await page.locator('#identifier').fill(id);
  if (kind==='show') await page.locator('#slot').fill(slot);
  if (kind==='music'||kind==='stop') await page.locator('#fade').fill(fade);
  await page.getByRole('button',{name:'Insert before line',exact:true}).click();
  assert.match(await page.locator('#message').innerText(),/Inserted/);
 }
 const bytes=Buffer.from('\uFEFF'+mixed);
 await load('preserve.dtl',bytes); assert.deepEqual(await exported(),bytes);
 await insert('checkpoint','room.arrival','\\Thought');
 assert.deepEqual(await exported(),Buffer.from('\uFEFF'+mixed.replace('\\Caption','# checkpoint room.arrival\r\n\\Caption')));
 await page.getByRole('button',{name:'Undo edit',exact:true}).click(); assert.deepEqual(await exported(),bytes);
 await load('Day1.dtl',Buffer.from(original)); assert.deepEqual(await exported(),Buffer.from(original));
 const caption='\\Sylvia slides';
 await insert('label','editor.preview',caption);
 await insert('background','picture3',caption);
 await insert('checkpoint','editor.arrival',caption);
 await insert('stop','',caption,'','0.4');
 // Manual text edits preserve the rest of the source, and local feedback links to its line.
 await page.locator('#source').fill((await page.locator('#source').inputValue())+'\nlabel editor.preview\n');
 assert.match(await page.locator('#issues').innerText(),/Duplicate label/);
 await page.getByRole('button',{name:'Undo edit',exact:true}).click();
 assert.equal(await page.locator('#issues').innerText(),'');
 const output=await exported();
 const expected=original.replace('# art scene draft.reading.early','label editor.preview\n# art scene draft.reading.early').replace(caption,'# art background picture3\n# checkpoint editor.arrival\n# audio music stop fade=0.4\n'+caption);
 assert.equal(output.toString(),expected);
 const artifact=process.env.EDITOR_ARTIFACT_DIR || path.join(__dirname,'artifacts'); fs.mkdirSync(artifact,{recursive:true});
 fs.writeFileSync(path.join(artifact,'Day1.dtl'),output);
 await page.screenshot({path:path.join(artifact,'desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await page.screenshot({path:path.join(artifact,'mobile.png'),fullPage:true});
 assert.deepEqual(errors,[]); await browser.close();
 console.log('PASS: browser import/export bytes, cue insertion, undo, feedback, real Day1 export and mobile layout.');
}
if (process.argv.includes('--browser')) browserJourney().catch(error=>{console.error(error);process.exitCode=1;});
