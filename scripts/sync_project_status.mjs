import { cp, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "..");
const source = path.join(repoRoot, "web", "project-status");
const buildRoot = path.join(repoRoot, "build", "web");
const destination = path.join(buildRoot, "project-status");

await mkdir(buildRoot, { recursive: true });
await rm(destination, { recursive: true, force: true });
await cp(source, destination, { recursive: true });

console.log(`Project status dashboard synced to ${destination}`);
console.log("Firebase Hosting route: /project-status/");
