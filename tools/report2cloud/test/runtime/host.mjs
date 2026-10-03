// The backend child of the report2cloud runtime test (backend.mjs):
//
//   node host.mjs <runtime dir> <apps dir>     PORT from the environment
//
// Resolves @abap2ui5/node-runtime from the runtime directory, boots the
// build (<apps dir>/init.mjs: the runtime, the tables and their seed rows, the
// classes) and serves it on loopback - mcp-server's lib/npm-host.mjs, for a
// build that is not the server's own apps/.
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const [dir, apps] = process.argv.slice(2).map((p) => resolve(p));
const port = Number(process.env.PORT || 3000);
try {
  const req = createRequire(join(dir, "package.json"));
  const runtime = await import(pathToFileURL(req.resolve("@abap2ui5/node-runtime")).href);
  const boot = await import(pathToFileURL(join(apps, "init.mjs")).href);
  await runtime.serve({ port, host: "127.0.0.1" });
  console.log(`report2cloud runtime host: ${boot.devModules.length} module(s)`);
  console.log(`Listening on ${port}`);
} catch (e) {
  console.error(`report2cloud runtime host: ${(e && e.stack) || e}`);
  process.exit(1);
}
