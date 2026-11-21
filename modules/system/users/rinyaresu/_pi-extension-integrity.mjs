import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, readlinkSync } from 'node:fs';
import { join } from 'node:path';

const [action, root, reference] = process.argv.slice(2);
const stamp = '.dots-dependencies.json';
const hash = (value) => createHash('sha256').update(value).digest('hex');
const read = (path) => JSON.parse(readFileSync(path, 'utf8'));
const tree = join(root, 'node_modules');

function fingerprint(base, dir = base) {
  return readdirSync(dir).sort().flatMap((name) => {
    if (dir === base && name === stamp) return [];
    const path = join(dir, name);
    const stat = lstatSync(path);
    const entry = [path.slice(base.length + 1), stat.mode];
    if (stat.isDirectory()) return [entry, ...fingerprint(base, path)];
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
  const entries = fingerprint(tree);
  const digest = hash(JSON.stringify(entries));
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
  } else if (action === 'matches') {
    // Allow npm's 022 vs 077 umask differences, but never ignore write
    // permissions, owner bits, or execute bits on non-executable files.
    const comparable = (entries) => entries
      // npm's generated cache can contain paths relative to the install root.
      // It is not evidence of integrity; the receipt still hashes its bytes.
      .filter(([path, mode]) => path !== '.package-lock.json' || (mode & 0o170000) !== 0o100000)
      .map(([path, mode, ...data]) => [
        path, mode & ~(0o044 | ((mode & 0o100) ? 0o011 : 0)), ...data,
      ]);
    if (JSON.stringify(comparable(entries)) === JSON.stringify(comparable(fingerprint(reference)))) {
      console.log(JSON.stringify({ ...read(join(reference, stamp)), digest }));
    } else {
      process.exitCode = 1;
    }
  } else {
    const path = join(tree, stamp);
    if (!lstatSync(path).isFile()) throw new Error('Invalid dependency receipt');
    const receipt = read(path);
    if (receipt.schema !== 1 || receipt.digest !== digest) throw new Error('Installed tree has changed');
    console.log(JSON.stringify(receipt.inputs));
  }
}
