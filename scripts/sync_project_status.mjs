import { cp, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "..");
const buildRoot = path.join(repoRoot, "build", "web");

const staticRoutes = [
  {
    name: "Project status dashboard",
    source: path.join(repoRoot, "web", "project-status"),
    destination: path.join(buildRoot, "project-status"),
    route: "/project-status/",
  },
  {
    name: "BGO test launcher",
    source: path.join(repoRoot, "web", "test-launcher"),
    destination: path.join(buildRoot, "test-launcher"),
    route: "/test-launcher/",
  },
];

await mkdir(buildRoot, { recursive: true });

for (const item of staticRoutes) {
  await rm(item.destination, { recursive: true, force: true });
  await cp(item.source, item.destination, { recursive: true });
  console.log(`${item.name} synced to ${item.destination}`);
  console.log(`Firebase Hosting route: ${item.route}`);
}
