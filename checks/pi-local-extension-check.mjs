import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [piBin, agentDir, scratch] = process.argv.slice(2);
const piEntry = join(dirname(piBin), '../lib/pi/node_modules/@earendil-works/pi-coding-agent/dist/index.js');
const { discoverAndLoadExtensions } = await import(pathToFileURL(piEntry));
const { extensions, errors } = await discoverAndLoadExtensions([], scratch, agentDir);
for (const { path, error } of errors) console.error(`${path}: ${error}`);
const expected = resolve(agentDir, 'extensions/herdr-codemode/index.ts');
if (errors.length || !extensions.some(({ path }) => path === expected)) {
  throw new Error('Falha ao carregar as extensões locais do Pi (herdr-codemode é obrigatória).');
}
console.log(`Pi: ${extensions.length} extensões locais carregadas (incluindo herdr-codemode).`);
