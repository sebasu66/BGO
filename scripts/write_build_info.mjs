import { execFileSync } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

function git(args, fallback = "") {
  try {
    return execFileSync("git", args, { encoding: "utf8" }).trim();
  } catch (_) {
    return fallback;
  }
}

const sha = process.env.GITHUB_SHA || git(["rev-parse", "HEAD"], "unknown");
const shortSha = sha.slice(0, 7);
const branch = process.env.GITHUB_REF_NAME || git(["branch", "--show-current"], "local");
const runNumber = process.env.GITHUB_RUN_NUMBER || "local";
const runId = process.env.GITHUB_RUN_ID || "local";
const environment = branch === "main" ? "PROD" : branch === "develop" ? "DEV" : "LOCAL";
const version = `${environment}-${runNumber}-${shortSha}`;
const builtAt = new Date().toISOString();

let changeRange = "";
if (environment === "DEV" && git(["rev-parse", "--verify", "origin/main"], "")) {
  changeRange = "origin/main..HEAD";
}

const logArgs = ["log", "--pretty=format:%h%x09%s%x09%an%x09%aI", "-n", "30"];
if (changeRange) logArgs.push(changeRange);

const rawLog = git(logArgs, "");
const changes = rawLog
  ? rawLog.split("\n").filter(Boolean).map((line) => {
      const [commit, subject, author, timestamp] = line.split("\t");
      return { commit, subject, author, timestamp };
    })
  : [];

const payload = {
  version,
  environment,
  deploy_number: runNumber,
  run_id: runId,
  commit: sha,
  short_commit: shortSha,
  branch,
  built_at: builtAt,
  change_basis: changeRange || "last 30 commits",
  changes,
};

await mkdir(path.join("build", "web"), { recursive: true });
await writeFile(
  path.join("build", "web", "build-info.json"),
  `${JSON.stringify(payload, null, 2)}\n`,
  "utf8",
);
console.log(`Build metadata: ${version}`);
console.log(`Changes: ${changes.length} (${payload.change_basis})`);
