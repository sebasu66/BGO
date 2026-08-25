import { cp, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "..");
const buildRoot = path.join(repoRoot, "build", "web");

const staticRoutes = [
  {
    name: "BGO DEV hub",
    source: path.join(repoRoot, "hosting", "dev"),
    destination: path.join(buildRoot, "dev"),
    route: "/dev/",
  },
  {
    name: "Project status dashboard",
    source: path.join(repoRoot, "hosting", "project-status"),
    destination: path.join(buildRoot, "project-status"),
    route: "/project-status/",
  },
  {
    name: "BGO test launcher",
    source: path.join(repoRoot, "hosting", "test-launcher"),
    destination: path.join(buildRoot, "test-launcher"),
    route: "/test-launcher/",
  },
  {
    name: "BGO latest error viewer",
    source: path.join(repoRoot, "hosting", "error-viewer"),
    destination: path.join(buildRoot, "error-viewer"),
    route: "/error-viewer/",
  },
  {
    name: "BGO user manual",
    source: path.join(repoRoot, "hosting", "help"),
    destination: path.join(buildRoot, "help"),
    route: "/help/",
  },
];

await mkdir(buildRoot, { recursive: true });

for (const item of staticRoutes) {
  await rm(item.destination, { recursive: true, force: true });
  await cp(item.source, item.destination, { recursive: true });
  console.log(`${item.name} synced to ${item.destination}`);
  console.log(`Firebase Hosting route: ${item.route}`);
}
