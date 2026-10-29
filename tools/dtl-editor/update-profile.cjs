// Refresh the self-contained editor from a successful Godot measurement report.
// Usage: node tools/dtl-editor/update-profile.cjs path/to/results.json
const fs = require('node:fs');
const path = require('node:path');
const report = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!report.ok || report.profiles.length !== 40 || !report.revision) throw Error('A complete, source-bound Godot report is required.');
const profile = {
 version: 1, pending: false,
 reference: {
  revision: report.revision, evidence: 'tests/ui/render_readability_measurements.gd',
  textPercent: 125, renderPixels: report.render_pixels, logical: report.logical_viewport,
  fonts: ['pixel','readable'], godot: report.godot,
  scope: 'Observed one-row boundaries for three rotations of committed prose, both fonts and mono/bilingual configurations. Lower end is a conservative editorial target, never a fit guarantee.',
 },
 locales: {},
};
for (const locale of ['en','zh_HK','zh_CN','ja','ko']) {
 const rows = report.profiles.filter(row => row.locale === locale && row.text_percent === 125);
 const segmenter = new Intl.Segmenter(locale.replace('_','-'), {granularity:'grapheme'});
 const count = text => Array.from(segmenter.segment(text)).length;
 profile.locales[locale] = {};
 for (const kind of ['caption','thought']) {
  const observations = rows.flatMap(row => row[kind].map(sample => ({
   font: row.font_style, dual: row.dual, characters: count(sample.one_row.text),
   width: sample.available_width, fontSize: sample.font_size,
   text: sample.one_row.text, nextPrefixRows: sample.one_row.next_prefix_rows,
  })));
  if (rows.length !== 4 || observations.some(sample => sample.nextPrefixRows <= 1)) throw Error('Missing measured row boundary: '+locale+'/'+kind);
  const counts = observations.map(sample=>sample.characters);
  const widths = [...new Set(observations.map(sample=>sample.width))];
  if (widths.length !== 1) throw Error('Reference width differs across profiles: '+locale+'/'+kind);
  profile.locales[locale][kind] = {width:widths[0], range:[Math.min(...counts),Math.max(...counts)], observations};
 }
}
if (process.argv.includes('--check')) {
 const committed = JSON.parse(fs.readFileSync(path.join(__dirname,'readability-profile.json'),'utf8'));
 for (const [locale,kinds] of Object.entries(profile.locales)) for (const [kind,value] of Object.entries(kinds)) {
  const expected=committed.locales[locale][kind];
  if (value.width!==expected.width || JSON.stringify(value.range)!==JSON.stringify(expected.range)) throw Error('Refresh the measured profile: '+locale+'/'+kind);
 }
 console.log('PASS: committed editorial ranges match the current Godot measurements.');
 process.exit(0);
}
fs.writeFileSync(path.join(__dirname,'readability-profile.json'),JSON.stringify(profile,null,2)+'\n');
const htmlPath=path.join(__dirname,'index.html');
const html=fs.readFileSync(htmlPath,'utf8');
fs.writeFileSync(htmlPath,html.replace(/^const READABILITY_PROFILE = .*;$/m,'const READABILITY_PROFILE = '+JSON.stringify(profile)+';'));
console.log(JSON.stringify(Object.fromEntries(Object.entries(profile.locales).map(([locale,kinds])=>[locale,Object.fromEntries(Object.entries(kinds).map(([kind,value])=>[kind,value.range]))])),null,2));
