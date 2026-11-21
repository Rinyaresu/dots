import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, readlinkSync } from 'node:fs';
import { join } from 'node:path';

const [action, root] = process.argv.slice(2);
const stamp = '.dots-dependencies.json';
const hash = (value) => createHash('sha256').update(value).digest('hex');
const read = (path) => JSON.parse(readFileSync(path, 'utf8'));
const tree = join(root, 'node_modules');

function fingerprint(dir = tree) {
  return readdirSync(dir).sort().flatMap((name) => {
    if (dir === tree && name === stamp) return [];
    const path = join(dir, name);
    const stat = lstatSync(path);
    const entry = [path.slice(tree.length + 1), stat.mode];
    if (stat.isDirectory()) return [entry, ...fingerprint(path)];
    if (stat.isSymbolicLink()) return [[...entry, readlinkSync(path)]];
    if (stat.isFile()) return [[...entry, hash(readFileSync(path))]];
    throw new Error(`Unsupported dependency entry: ${path}`);
  });
}

function inputs() {
  return ['package.json', 'package-lock.json'].map((name) => hash(readFileSync(join(root, name))));
}

if (action === 'inputs') {
  console.log(JSON.stringify(inputs()));
} else {
  if (!lstatSync(tree).isDirectory()) throw new Error('node_modules is not a real directory');
  const digest = hash(JSON.stringify(fingerprint()));
  if (action === 'record') {
    // npm ci verifies each tarball's SRI. Confirm the resulting installed
    // manifests against lockfile paths, including transitive dependencies.
    const { lockfileVersion, packages } = read(join(root, 'package-lock.json'));
    if (lockfileVersion !== 3 || !packages?.['']) throw new Error('Expected npm lockfile v3');
    for (const [name, pkg] of Object.entries(packages)) {
      if (!name || pkg.dev) continue;
      if (!name.startsWith('node_modules/') || name.split('/').some((part) => ['.', '..', ''].includes(part))) {
        throw new Error(`Unexpected lockfile path: ${name}`);
      }
      let installed;
      try {
        installed = read(join(root, name, 'package.json'));
      } catch (error) {
        if (pkg.optional && error.code === 'ENOENT') continue;
        throw error;
      }
      if (pkg.link || !pkg.integrity || installed.version !== pkg.version) {
        throw new Error(`Installed package does not match the lockfile: ${name}`);
      }
    }
    console.log(JSON.stringify({ schema: 1, inputs: inputs(), digest }));
  } else {
    const path = join(tree, stamp);
    if (!lstatSync(path).isFile()) throw new Error('Invalid dependency receipt');
    const receipt = read(path);
    if (receipt.schema !== 1 || receipt.digest !== digest) throw new Error('Installed tree has changed');
    console.log(JSON.stringify(receipt.inputs));
  }
}
