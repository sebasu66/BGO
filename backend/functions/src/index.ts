import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { defineString } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { createBgoMcpServer, type BgoMcpContext } from "./server.js";
import { FirebaseBgoSessionStore } from "./store.js";
import { BGO_DEV_ALLOWED_HOSTS } from "./deployment.js";

const databaseUrl = defineString("BGO_FIREBASE_DATABASE_URL", {
  default: "https://board-game-online-68c3f-default-rtdb.firebaseio.com",
});
const environment = defineString("BGO_MCP_ENVIRONMENT", { default: "dev" });
const sessionId = defineString("BGO_MCP_SESSION_ID", { default: "TEST001" });
const participantId = defineString("BGO_MCP_PARTICIPANT_ID", { default: "host" });
const participantRole = defineString("BGO_MCP_ROLE", { default: "host" });

const app = createMcpExpressApp({ allowedHosts: BGO_DEV_ALLOWED_HOSTS });

app.get("/health", (_request, response) => {
  response.json({ service: "bgo-mcp", version: "0.2.0", environment: environment.value() });
});

app.post("/mcp", async (request, response) => {
  if (environment.value() !== "dev") {
    response.status(503).json({ error: "The no-auth MCP prototype is DEV-only." });
    return;
  }
  const role = participantRole.value();
  if (!(["host", "player", "spectator", "display"] as const).includes(role as BgoMcpContext["role"])) {
    response.status(500).json({ error: "Invalid BGO_MCP_ROLE configuration." });
    return;
  }

  const context: BgoMcpContext = {
    environment: "dev",
    sessionId: sessionId.value(),
    participantId: participantId.value(),
    role: role as BgoMcpContext["role"],
  };
  const store = new FirebaseBgoSessionStore(databaseUrl.value());
  const server = createBgoMcpServer(store, context);
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  response.on("close", () => {
    void transport.close();
    void server.close();
  });
  try {
    await server.connect(transport);
    await transport.handleRequest(request, response, request.body);
  } catch (error) {
    console.error("BGO MCP request failed", error);
    if (!response.headersSent) {
      response.status(500).json({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      });
    }
  }
});

app.all("/mcp", (_request, response) => {
  response.status(405).json({
    jsonrpc: "2.0",
    error: { code: -32000, message: "Method not allowed" },
    id: null,
  });
});

export const bgoMcpDev = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "512MiB",
    maxInstances: 3,
    cors: false,
  },
  app,
);
