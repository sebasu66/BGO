import { readFile, writeFile } from "node:fs/promises";

const target = "build/web/index.html";
let html = await readFile(target, "utf8");
if (html.includes('id="bgo-build-badge"')) {
  console.log("Build badge already present");
  process.exit(0);
}

const badge = `
<div id="bgo-build-badge" style="position:fixed;right:10px;top:10px;z-index:2147483647;max-width:270px;padding:8px 10px;border-radius:9px;background:rgba(15,17,22,.86);border:1px solid rgba(255,255,255,.18);color:#eef0f6;font:11px/1.35 ui-monospace,SFMono-Regular,Menlo,monospace;backdrop-filter:blur(6px);pointer-events:none">
  <div id="bgo-build-text">BGO · cargando build…</div>
  <a href="/dev/" style="pointer-events:auto;color:#8bb6ff;text-decoration:none;font-weight:700">DEV HUB / LOBBY</a>
</div>
<script>
fetch('/build-info.json?t=' + Date.now(), {cache:'no-store'}).then(function(r){return r.json()}).then(function(i){
  var d = new Date(i.built_at);
  document.getElementById('bgo-build-text').textContent = i.version + ' · deploy #' + i.deploy_number + ' · ' + d.toLocaleString();
}).catch(function(){ document.getElementById('bgo-build-text').textContent='BGO · build info unavailable'; });
</script>
`;

html = html.replace("</body>", `${badge}\n</body>`);
await writeFile(target, html, "utf8");
console.log("Injected BGO build badge into Web shell");
