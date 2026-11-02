import { readFile, readdir } from 'node:fs/promises';
import { checkClassicSyntax } from './lib/classic-syntax.mjs';

const root = new URL('../', import.meta.url);
let count = 0;
for (const file of [...(await readdir(new URL('abap/', root))).map(name => `abap/${name}`), 'installer/head.abap']) {
  if (!file.endsWith('.abap')) continue;
  const source = await readFile(new URL(file, root), 'utf8');
  for (const issue of checkClassicSyntax(source)) {
    console.error(`${file}:${issue.line}: ${issue.message}`);
    count++;
  }
}
if (count) process.exitCode = 1;
else console.log('Classic ABAP compatibility gate passed.');
