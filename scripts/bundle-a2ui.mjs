#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

if (process.platform === "win32") {
  // Keep prebuilt bundle on Windows dev installs to avoid requiring WSL/Git Bash.
  console.log("A2UI bundling skipped on Windows (using prebuilt bundle).");
  process.exit(0);
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const scriptPath = path.join(__dirname, "bundle-a2ui.sh");

const res = spawnSync("bash", [scriptPath], { stdio: "inherit" });
if (typeof res.status === "number") process.exit(res.status);
process.exit(1);
