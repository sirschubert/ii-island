import fs from 'node:fs';
import vm from 'node:vm';

export function loadJs(path) {
  const ctx = {};
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path, 'utf8'), ctx);
  return ctx;
}
