#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { promises as fs } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const a2uiDir = path.join(repoRoot, "src", "canvas-host", "a2ui");
const bundlePath = path.join(a2uiDir, "a2ui.bundle.js");

if (process.platform === "win32") {
  // Windows local installs should not require WSL/Git Bash.
  // Ensure bundle file exists so downstream copy step succeeds.
  await fs.mkdir(a2uiDir, { recursive: true });
  try {
    await fs.access(bundlePath);
    console.log("A2UI bundling skipped on Windows (existing bundle retained).");
  } catch {
    await fs.writeFile(
      bundlePath,
      "/* WinClaw placeholder A2UI bundle for Windows builds (no WSL). */\nwindow.__OPENCLAW_A2UI_BUNDLE__ = window.__OPENCLAW_A2UI_BUNDLE__ || {};\n",
      "utf8",
    );
    console.log("A2UI bundling skipped on Windows (placeholder bundle created).");
  }
  process.exit(0);
}

const scriptPath = path.join(__dirname, "bundle-a2ui.sh");

const res = spawnSync("bash", [scriptPath], { stdio: "inherit" });
if (typeof res.status === "number") process.exit(res.status);
process.exit(1);
