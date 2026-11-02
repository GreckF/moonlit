// Runs the kernel in a worker thread with a large stack: the type checker is
// deeply recursive, and the main thread's stack is small (1 MB on Windows).
import { Worker } from "node:worker_threads";

const w = new Worker(new URL("./moonlit.mjs", import.meta.url), {
  argv: process.argv.slice(2),
  resourceLimits: { stackSizeMb: 1024, maxOldGenerationSizeMb: 8192 },
});
w.on("error", (e) => {
  console.log("ERROR " + (e && e.message ? e.message : e));
  process.exit(2);
});
w.on("exit", (code) => process.exit(code));
