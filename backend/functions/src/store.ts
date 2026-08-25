import { getApps, initializeApp } from "firebase-admin/app";
import { getDatabase, ServerValue } from "firebase-admin/database";

export type JsonObject = Record<string, unknown>;

export interface McpCommand {
  tool:
    | "bgo_create_object_at_point"
    | "bgo_move_object_to_point"
    | "bgo_set_properties"
    | "bgo_execute";
  context: {
    session_id: string;
    participant_id: string;
    role: string;
  };
  arguments: JsonObject;
}

export interface CommandResult {
  command_id: string;
  status: "completed" | "rejected" | "pending" | "timeout";
  result?: JsonObject;
  reason?: string;
}

export interface BgoSessionStore {
  getSession(sessionId: string): Promise<JsonObject | null>;
  getDefinition(sessionId: string): Promise<JsonObject | null>;
  enqueueCommand(sessionId: string, command: McpCommand): Promise<CommandResult>;
}

const sleep = (milliseconds: number) =>
  new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

export class FirebaseBgoSessionStore implements BgoSessionStore {
  constructor(
    private readonly databaseUrl: string,
    private readonly waitTimeoutMs = 10_000,
  ) {}

  private database() {
    if (getApps().length === 0) {
      initializeApp({ databaseURL: this.databaseUrl });
    }
    return getDatabase();
  }

  async getSession(sessionId: string): Promise<JsonObject | null> {
    const snapshot = await this.database().ref(`games/${sessionId}`).get();
    return snapshot.exists() ? (snapshot.val() as JsonObject) : null;
  }

  async getDefinition(sessionId: string): Promise<JsonObject | null> {
    const snapshot = await this.database().ref(`games/${sessionId}/definition`).get();
    return snapshot.exists() ? (snapshot.val() as JsonObject) : null;
  }

  async enqueueCommand(sessionId: string, command: McpCommand): Promise<CommandResult> {
    const commandRef = this.database().ref(`games/${sessionId}/mcp_commands`).push();
    const commandId = commandRef.key;
    if (!commandId) {
      throw new Error("Firebase did not allocate a command id.");
    }
    await commandRef.set({
      ...command,
      status: "pending",
      requested_at: ServerValue.TIMESTAMP,
    });

    const deadline = Date.now() + this.waitTimeoutMs;
    while (Date.now() < deadline) {
      const snapshot = await commandRef.get();
      const value = (snapshot.val() ?? {}) as JsonObject;
      const status = String(value.status ?? "pending");
      if (status === "completed" || status === "rejected") {
        return {
          command_id: commandId,
          status,
          result: isObject(value.result) ? value.result : undefined,
          reason: typeof value.reason === "string" ? value.reason : undefined,
        };
      }
      await sleep(250);
    }
    return { command_id: commandId, status: "timeout" };
  }
}

export function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
