// Summarize a .cpuprofile: self and total time per function (top 30).
import { readFileSync } from "node:fs";
const p = JSON.parse(readFileSync(process.argv[2], "utf8"));
const byId = new Map(p.nodes.map((n) => [n.id, n]));
const self = new Map();
const dt = new Map();
for (let i = 0; i < p.samples.length; i++) {
  const id = p.samples[i];
  dt.set(id, (dt.get(id) || 0) + (p.timeDeltas[i] || 0));
}
const parent = new Map();
for (const n of p.nodes) for (const c of n.children || []) parent.set(c, n.id);
const total = new Map();
for (const [id, t] of dt) {
  const name = byId.get(id).callFrame.functionName || "(anon)";
  self.set(name, (self.get(name) || 0) + t);
  const seen = new Set();
  for (let cur = id; cur !== undefined; cur = parent.get(cur)) {
    const nm = byId.get(cur).callFrame.functionName || "(anon)";
    if (seen.has(nm)) continue;
    seen.add(nm);
    total.set(nm, (total.get(nm) || 0) + t);
  }
}
const all = [...dt.values()].reduce((a, b) => a + b, 0);
const show = (m, title) => {
  console.log(title);
  for (const [n, t] of [...m].sort((a, b) => b[1] - a[1]).slice(0, 30))
    console.log(((100 * t) / all).toFixed(1).padStart(6) + "%  " + n.replace(/^_M0FP38username7moonlit4main/, ""));
};
show(self, "== self");
show(total, "== total");
