const $ = (id) => document.getElementById(id);

const STATUS_CLASS = {
  pass: "good",
  success: "good",
  done: "good",
  healthy: "good",
  warning: "warn",
  blocked: "bad",
  fail: "bad",
  failure: "bad",
  cancelled: "bad",
  pending: "neutral",
  planned: "neutral",
  unknown: "neutral",
  active: "warn"
};

function badge(label, status = "unknown") {
  const cls = STATUS_CLASS[status] || "neutral";
  return `<span class="badge ${cls}">${label}</span>`;
}

function statusDot(status = "unknown") {
  const cls = STATUS_CLASS[status] || "neutral";
  return `<span class="status-dot ${cls}"></span>`;
}

function renderSummary(data) {
  const tests = data.health_checks || [];
  const passed = tests.filter((item) => item.status === "pass").length;
  const blockers = (data.blockers || []).filter((item) => item.status !== "done").length;
  const donePhases = (data.core_roadmap || []).filter((item) => item.status === "done").length;
  const totalPhases = (data.core_roadmap || []).length;

  $("summary-grid").innerHTML = [
    ["Checkpoint", data.current_checkpoint?.id || "—", data.current_checkpoint?.title || "Sin checkpoint definido"],
    ["Quality checks", `${passed}/${tests.length}`, tests.length ? "Checks confirmados como PASS" : "Aún sin resultados automáticos"],
    ["Bloqueos abiertos", String(blockers), blockers === 0 ? "Sin bloqueos reportados" : "Requieren atención antes de avanzar"],
    ["Roadmap core", `${donePhases}/${totalPhases}`, "Fases completadas"],
  ].map(([label, value, sub]) => `
    <article class="summary-card">
      <div class="label">${label}</div>
      <div class="value">${value}</div>
      <div class="sub">${sub}</div>
    </article>`).join("");
}

function renderCurrentCheckpoint(data) {
  const current = data.current_checkpoint || {};
  const progress = Number.isFinite(current.progress_percent) ? current.progress_percent : 0;
  $("current-checkpoint").innerHTML = `
    <div class="checkpoint-card">
      <div>
        <div>${badge(current.status_label || "EN PROGRESO", current.status || "active")}</div>
        <h3 class="checkpoint-title">${current.id || "—"} · ${current.title || "Sin definir"}</h3>
        <p class="checkpoint-copy">${current.description || ""}</p>
        ${current.next_action ? `<p class="roadmap-meta"><strong>Siguiente:</strong> ${current.next_action}</p>` : ""}
      </div>
      <div>
        <div class="progress-track" aria-label="Progreso del checkpoint">
          <div class="progress-fill" style="width:${Math.max(0, Math.min(100, progress))}%"></div>
        </div>
        <span class="progress-label">${progress}% estimado</span>
      </div>
    </div>`;
}

function renderHealth(data) {
  const checks = data.health_checks || [];
  if (!checks.length) {
    $("health-checks").innerHTML = `<p class="muted">Todavía no hay checks conectados.</p>`;
    return;
  }

  $("health-checks").innerHTML = checks.map((item) => `
    <div class="check-row">
      ${statusDot(item.status)}
      <div>
        <div class="check-name">${item.name}</div>
        <div class="check-detail">${item.detail || ""}</div>
      </div>
      ${badge(item.label || item.status.toUpperCase(), item.status)}
    </div>`).join("");
}

function renderBlockers(data) {
  const blockers = data.blockers || [];
  if (!blockers.length) {
    $("blockers").innerHTML = `<p class="muted">Sin bloqueos reportados.</p>`;
    return;
  }

  $("blockers").innerHTML = blockers.map((item) => `
    <div class="blocker">
      ${statusDot(item.status)}
      <div>
        <div class="check-name">${item.title}</div>
        <div class="blocker-detail">${item.detail || ""}</div>
      </div>
      ${badge(item.label || item.status.toUpperCase(), item.status)}
    </div>`).join("");
}

function renderRoadmap(targetId, items) {
  $(targetId).innerHTML = (items || []).map((item) => `
    <article class="roadmap-item ${item.status === "active" ? "active" : ""}">
      <div class="roadmap-index">${item.id}</div>
      <div>
        <div class="roadmap-title">${item.title}</div>
        <div class="roadmap-copy">${item.description || ""}</div>
        ${item.checkpoint ? `<div class="roadmap-meta"><strong>Checkpoint:</strong> ${item.checkpoint}</div>` : ""}
      </div>
      ${badge(item.label || item.status.toUpperCase(), item.status)}
    </article>`).join("");
}

function renderCi(data) {
  const ci = data.ci || {};
  const checks = [
    ["Format", ci.format],
    ["Lint", ci.lint],
    ["Structure", ci.structure],
    ["Godot import", ci.godot_import],
    ["Tests", ci.tests],
    ["Web export", ci.web_export],
  ].filter(([, value]) => value);

  $("ci-details").innerHTML = `
    <div class="ci-grid">
      <div class="ci-cell">
        <div class="label">Estado</div>
        <div class="value">${badge((ci.label || "NO CONECTADO").toUpperCase(), ci.status || "unknown")}</div>
      </div>
      <div class="ci-cell">
        <div class="label">Commit</div>
        <div class="value">${ci.commit || "—"}</div>
      </div>
      <div class="ci-cell">
        <div class="label">Workflow / ejecución</div>
        <div class="value">${ci.run || "Todavía no disponible"}</div>
      </div>
    </div>
    ${checks.length ? `<div class="ci-grid">${checks.map(([name, value]) => `<div class="ci-cell"><div class="label">${name}</div><div class="value">${badge(String(value).toUpperCase(), value)}</div></div>`).join("")}</div>` : ""}
    ${ci.note ? `<p class="muted">${ci.note}</p>` : ""}`;
}

function renderOverall(data) {
  const overall = data.overall || { status: "unknown", label: "DESCONOCIDO" };
  const target = $("overall-badge");
  target.className = `badge ${STATUS_CLASS[overall.status] || "neutral"}`;
  target.textContent = overall.label;
}

function render(data) {
  renderOverall(data);
  renderSummary(data);
  renderCurrentCheckpoint(data);
  renderHealth(data);
  renderBlockers(data);
  renderRoadmap("core-roadmap", data.core_roadmap || []);
  renderRoadmap("web-roadmap", data.web_roadmap || []);
  renderCi(data);

  const updated = data.updated_at ? new Date(data.updated_at) : null;
  $("last-updated").textContent = updated && !Number.isNaN(updated.valueOf())
    ? `Actualizado ${updated.toLocaleString()}`
    : "Fecha de actualización no disponible";
}

async function fetchJson(path) {
  const response = await fetch(`${path}?t=${Date.now()}`, { cache: "no-store" });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}

async function loadStatus() {
  try {
    const data = await fetchJson("./status.json");
    try {
      const ci = await fetchJson("./ci.json");
      data.ci = { ...(data.ci || {}), ...ci };
    } catch (_) {
      // ci.json is optional until CI/deployment integration is active.
    }
    render(data);
  } catch (error) {
    $("overall-badge").className = "badge bad";
    $("overall-badge").textContent = "ERROR DE DATOS";
    $("current-checkpoint").innerHTML = `<div class="error-box">No se pudo cargar status.json: ${error.message}</div>`;
  }
}

$("refresh-button").addEventListener("click", loadStatus);
loadStatus();
