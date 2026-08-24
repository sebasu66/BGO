import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { BgoSessionStore, JsonObject, McpCommand } from "./store.js";
import { isObject } from "./store.js";

export interface BgoMcpContext {
  environment: "dev";
  sessionId: string;
  participantId: string;
  role: "host" | "player" | "spectator" | "display";
}

const readAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
};

const writeAnnotations = {
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: false,
  openWorldHint: false,
};

function toolResult(data: JsonObject) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data) }],
    structuredContent: data,
  };
}

function piecesFrom(session: JsonObject): JsonObject {
  return isObject(session.pieces) ? session.pieces : {};
}

function canViewPiece(context: BgoMcpContext, value: unknown): boolean {
  if (!isObject(value)) return false;
  if (context.role === "host") return true;
  const location = isObject(value.location) ? value.location : {};
  if (String(location.type ?? "") !== "hand") return String(value.visibility ?? "public") === "public";
  return (
    String(value.owner_id ?? "") === context.participantId ||
    String(value.holder_id ?? "") === context.participantId
  );
}

function visiblePieces(session: JsonObject, context: BgoMcpContext): JsonObject {
  return Object.fromEntries(
    Object.entries(piecesFrom(session)).filter(([, value]) => canViewPiece(context, value)),
  );
}

function visibleSession(session: JsonObject, context: BgoMcpContext): JsonObject {
  const filtered: JsonObject = { ...session, pieces: visiblePieces(session, context) };
  delete filtered.mcp_commands;
  delete filtered.events;
  return filtered;
}

const objectPrefix = "Match.objects.";
const objectPropertySchema: JsonObject = {
  componentId: { type: "string", writable: false },
  configuration: { type: "object", writable: true, authority: "owner" },
  quantity: { type: "integer", minimum: 1, writable: true, authority: "host" },
  availability: { type: "string", writable: false },
  availableQuantity: { type: "integer", writable: false },
  ownerId: { type: "string", writable: true, authority: "host" },
  holderId: { type: "string", writable: false },
  visibility: { type: "string", enum: ["public", "owner_only"], writable: true, authority: "owner" },
  location: { type: "object", writable: false },
};

function objectFromEntity(session: JsonObject, context: BgoMcpContext, entity: string) {
  if (!entity.startsWith(objectPrefix)) return null;
  const value = visiblePieces(session, context)[entity.slice(objectPrefix.length)];
  return isObject(value) ? value : null;
}

function objectProperties(value: JsonObject): JsonObject {
  const location = isObject(value.location) ? value.location : {};
  const cell = isObject(value.cell) ? value.cell : {};
  const origin = isObject(location.origin) ? location.origin : cell;
  const footprint = isObject(location.footprint)
    ? location.footprint
    : isObject(value.footprint)
      ? value.footprint
      : {};
  return {
    componentId: String(value.component_id ?? ""),
    configuration: isObject(value.object_config) ? value.object_config : {},
    quantity: Number(value.quantity ?? 1),
    availability: String(value.availability ?? "unique"),
    availableQuantity: Number(value.available_quantity ?? value.quantity ?? 1),
    ownerId: String(value.owner_id ?? ""),
    holderId: String(value.holder_id ?? ""),
    visibility: String(value.visibility ?? "public"),
    location: {
      type: String(location.type ?? ""),
      id: String(location.slot_id ?? location.player_id ?? location.box_id ?? ""),
      origin: { x: Number(origin.x ?? -1), y: Number(origin.y ?? -1) },
      footprint: { x: Number(footprint.x ?? 1), y: Number(footprint.y ?? 1) },
    },
  };
}

function objectCommands(context: BgoMcpContext): string[] {
  return context.role === "host" ? ["moveToPoint", "changeOwner"] : [];
}

function propertySchema(context: BgoMcpContext): JsonObject {
  return Object.fromEntries(
    Object.entries(objectPropertySchema).map(([name, descriptor]) => [
      name,
      isObject(descriptor)
        ? {
            ...descriptor,
            writable:
              context.role === "host" &&
              ["configuration", "quantity", "ownerId", "visibility"].includes(name),
          }
        : descriptor,
    ]),
  );
}

function queuedToolResult(command: Awaited<ReturnType<BgoSessionStore["enqueueCommand"]>>) {
  const accepted = command.status === "completed" && command.result?.ok === true;
  return toolResult({
    ok: accepted,
    reason:
      command.status === "timeout"
        ? "godot_authority_timeout"
        : accepted
          ? undefined
          : String(command.result?.reason ?? command.reason ?? command.status),
    command,
  });
}

function gridObject(objectId: string, value: unknown): JsonObject | null {
  if (!isObject(value)) return null;
  const cell = isObject(value.cell) ? value.cell : {};
  const location = isObject(value.location) ? value.location : {};
  const footprint = isObject(value.footprint) ? value.footprint : {};
  return {
    object_id: objectId,
    component_id: String(value.component_id ?? ""),
    owner_id: String(value.owner_id ?? ""),
    holder_id: String(value.holder_id ?? ""),
    quantity: Number(value.quantity ?? 1),
    location_type: String(location.type ?? ""),
    origin: { x: Number(cell.x ?? -1), y: Number(cell.y ?? -1) },
    footprint: { x: Number(footprint.x ?? 1), y: Number(footprint.y ?? 1) },
  };
}

function gridDefinition(definition: JsonObject | null): JsonObject {
  const table = definition && isObject(definition.table) ? definition.table : {};
  const instances = Array.isArray(table.instances) ? table.instances : [];
  for (const candidate of instances) {
    if (!isObject(candidate) || !String(candidate.component ?? "").startsWith("bgo.board.")) continue;
    const config = isObject(candidate.config) ? candidate.config : {};
    const spacing = Number(config.grid_cell_size_cm ?? 1);
    return {
      point_columns: Number(config.columns ?? 0),
      point_rows: Number(config.rows ?? 0),
      point_spacing_cm: { x: spacing, y: spacing },
    };
  }
  return {};
}

export function createBgoMcpServer(store: BgoSessionStore, context: BgoMcpContext) {
  const server = new McpServer(
    { name: "bgo-dev", version: "0.2.0" },
    {
      instructions:
        "Operate only on the bound BGO DEV session. Read logical state before mutations. " +
        "Grid coordinates are points, not world-space positions. Write tools queue commands " +
        "for validation by the active Godot authority and may time out when no authority is online.",
    },
  );

  server.registerTool(
    "bgo_get_context",
    {
      title: "Get BGO session context",
      description: "Returns the fixed DEV session, participant, and role bound to this MCP server.",
      inputSchema: {},
      annotations: readAnnotations,
    },
    async () =>
      toolResult({
        environment: context.environment,
        auth_mode: "dev_direct_no_auth",
        session_id: context.sessionId,
        participant_id: context.participantId,
        role: context.role,
      }),
  );

  server.registerTool(
    "bgo_get_definition",
    {
      title: "Get game definition",
      description: "Returns the declarative game definition pinned to the bound session.",
      inputSchema: {},
      annotations: readAnnotations,
    },
    async () => {
      const definition = await store.getDefinition(context.sessionId);
      return toolResult(
        definition ? { ok: true, definition } : { ok: false, reason: "definition_unavailable" },
      );
    },
  );

  server.registerTool(
    "bgo_get_entities",
    {
      title: "List BGO logical entities",
      description:
        "Lists the Game.*, Match.*, and visible Match.objects.* entities available in the bound session, including their declared commands.",
      inputSchema: {},
      annotations: readAnnotations,
    },
    async () => {
      const session = await store.getSession(context.sessionId);
      if (!session) return toolResult({ ok: false, reason: "session_missing" });
      const entities: JsonObject[] = [
        { entity: "Game.definition", class: "GameDefinition", writable: false, commands: [] },
        { entity: "Match", class: "Match", writable: false, commands: context.role === "host" ? ["createObjectAtPoint"] : [] },
        { entity: "Match.table", class: "Table", writable: false, commands: [] },
        { entity: "System.api", class: "SystemApi", writable: false, commands: [] },
        ...Object.keys(visiblePieces(session, context)).map((objectId) => ({
          entity: `${objectPrefix}${objectId}`,
          class: "GameObject",
          writable: context.role === "host",
          commands: objectCommands(context),
        })),
      ];
      entities.sort((left, right) => String(left.entity).localeCompare(String(right.entity)));
      return toolResult({ ok: true, entities });
    },
  );

  server.registerTool(
    "bgo_get_properties",
    {
      title: "Get BGO entity properties",
      description:
        "Returns an authorized property snapshot, writable schema, and declared commands for one entity returned by bgo_get_entities.",
      inputSchema: { entity: z.string().min(1) },
      annotations: readAnnotations,
    },
    async ({ entity }) => {
      const [session, definition] = await Promise.all([
        store.getSession(context.sessionId),
        store.getDefinition(context.sessionId),
      ]);
      if (!session) return toolResult({ ok: false, reason: "session_missing" });
      if (entity === "Game.definition") {
        return toolResult({ ok: true, entity, properties: definition ?? {}, schema: {}, commands: [] });
      }
      if (entity === "Match") {
        return toolResult({ ok: true, entity, properties: visibleSession(session, context), schema: {}, commands: context.role === "host" ? ["createObjectAtPoint"] : [] });
      }
      if (entity === "Match.table") {
        return toolResult({ ok: true, entity, properties: { grid: gridDefinition(definition) }, schema: {}, commands: [] });
      }
      if (entity === "System.api") {
        return toolResult({
          ok: true,
          entity,
          properties: {
            apiVersion: "0.2.0",
            roots: ["Game", "Match", "System"],
            tools: ["getEntities", "getProperties", "setProperties", "execute"],
          },
          schema: {},
          commands: [],
        });
      }
      const object = objectFromEntity(session, context, entity);
      return object
        ? toolResult({ ok: true, entity, properties: objectProperties(object), schema: propertySchema(context), commands: objectCommands(context) })
        : toolResult({ ok: false, reason: "unknown_or_hidden_entity" });
    },
  );

  server.registerTool(
    "bgo_set_properties",
    {
      title: "Set BGO entity properties",
      description:
        "Queues validated changes to declared writable properties. It cannot move, create, or delete entities.",
      inputSchema: {
        entity: z.string().startsWith(objectPrefix),
        changes: z.record(z.string(), z.unknown()),
      },
      annotations: writeAnnotations,
    },
    async ({ entity, changes }) => {
      if (context.role !== "host") return toolResult({ ok: false, reason: "host_required" });
      const keys = Object.keys(changes);
      const writable = ["configuration", "quantity", "ownerId", "visibility"];
      if (keys.length === 0) return toolResult({ ok: false, reason: "empty_changes" });
      const rejected = keys.find((key) => !writable.includes(key));
      if (rejected) return toolResult({ ok: false, reason: `property_not_writable:${rejected}` });
      const command: McpCommand = {
        tool: "bgo_set_properties",
        context: { session_id: context.sessionId, participant_id: context.participantId, role: context.role },
        arguments: { entity, changes },
      };
      return queuedToolResult(await store.enqueueCommand(context.sessionId, command));
    },
  );

  server.registerTool(
    "bgo_execute",
    {
      title: "Execute a BGO entity command",
      description:
        "Queues one declared domain command. Supported now: Match.createObjectAtPoint and GameObject.moveToPoint/changeOwner.",
      inputSchema: {
        entity: z.string().min(1),
        command: z.enum(["createObjectAtPoint", "moveToPoint", "changeOwner"]),
        arguments: z.record(z.string(), z.unknown()).default({}),
      },
      annotations: writeAnnotations,
    },
    async ({ entity, command: commandName, arguments: commandArguments }) => {
      if (context.role !== "host") return toolResult({ ok: false, reason: "host_required" });
      const allowed =
        (entity === "Match" && commandName === "createObjectAtPoint") ||
        (entity.startsWith(objectPrefix) && ["moveToPoint", "changeOwner"].includes(commandName));
      if (!allowed) return toolResult({ ok: false, reason: "command_not_allowed" });
      const command: McpCommand = {
        tool: "bgo_execute",
        context: { session_id: context.sessionId, participant_id: context.participantId, role: context.role },
        arguments: { entity, command: commandName, arguments: commandArguments },
      };
      return queuedToolResult(await store.enqueueCommand(context.sessionId, command));
    },
  );

  server.registerTool(
    "bgo_get_state",
    {
      title: "Get session state",
      description: "Returns the current logical Firebase projection for the bound DEV session.",
      inputSchema: {},
      annotations: readAnnotations,
    },
    async () => {
      const session = await store.getSession(context.sessionId);
      return toolResult(
        session
          ? { ok: true, state: visibleSession(session, context) }
          : { ok: false, reason: "session_missing" },
      );
    },
  );

  server.registerTool(
    "bgo_get_grid_state",
    {
      title: "Get tabletop grid state",
      description: "Lists table objects with logical point origins and footprints.",
      inputSchema: {},
      annotations: readAnnotations,
    },
    async () => {
      const [session, definition] = await Promise.all([
        store.getSession(context.sessionId),
        store.getDefinition(context.sessionId),
      ]);
      if (!session) return toolResult({ ok: false, reason: "session_missing" });
      const objects = Object.entries(visiblePieces(session, context))
        .map(([id, value]) => gridObject(id, value))
        .filter((value): value is JsonObject => value !== null)
        .sort((left, right) => String(left.object_id).localeCompare(String(right.object_id)));
      return toolResult({ ok: true, grid: gridDefinition(definition), objects });
    },
  );

  server.registerTool(
    "bgo_objects_at_point",
    {
      title: "Get objects at grid point",
      description: "Returns object IDs whose logical origin is the requested table-grid point.",
      inputSchema: { x: z.number().int().min(0), y: z.number().int().min(0) },
      annotations: readAnnotations,
    },
    async ({ x, y }) => {
      const session = await store.getSession(context.sessionId);
      if (!session) return toolResult({ ok: false, reason: "session_missing" });
      const objectIds = Object.entries(visiblePieces(session, context))
        .filter(([, value]) => {
          const object = gridObject("", value);
          const origin = object && isObject(object.origin) ? object.origin : {};
          const footprint = object && isObject(object.footprint) ? object.footprint : {};
          const originX = Number(origin.x ?? -1);
          const originY = Number(origin.y ?? -1);
          return (
            x >= originX &&
            x < originX + Number(footprint.x ?? 1) &&
            y >= originY &&
            y < originY + Number(footprint.y ?? 1)
          );
        })
        .map(([id]) => id)
        .sort();
      return toolResult({ ok: true, point: { x, y }, object_ids: objectIds });
    },
  );

  server.registerTool(
    "bgo_inspect_object",
    {
      title: "Inspect game object",
      description: "Returns the logical state of one game object by stable object ID.",
      inputSchema: { object_id: z.string().min(1) },
      annotations: readAnnotations,
    },
    async ({ object_id }) => {
      const session = await store.getSession(context.sessionId);
      const object = session ? visiblePieces(session, context)[object_id] : undefined;
      return toolResult(
        isObject(object)
          ? { ok: true, object: gridObject(object_id, object), state: object }
          : { ok: false, reason: "unknown_object" },
      );
    },
  );

  server.registerTool(
    "bgo_create_object_at_point",
    {
      title: "Create sandbox object at grid point",
      description:
        "Queues a host-only request to create a catalog component at a logical grid point.",
      inputSchema: {
        catalog_id: z.string().min(1),
        object_id: z.string().min(1),
        x: z.number().int().min(0),
        y: z.number().int().min(0),
        owner_id: z.string().default(""),
        configuration: z.record(z.string(), z.unknown()).default({}),
        footprint_x: z.number().int().min(1).default(1),
        footprint_y: z.number().int().min(1).default(1),
        allow_overlap: z.boolean().default(false),
      },
      annotations: writeAnnotations,
    },
    async (args) => {
      if (context.role !== "host") return toolResult({ ok: false, reason: "host_required" });
      const command: McpCommand = {
        tool: "bgo_create_object_at_point",
        context: {
          session_id: context.sessionId,
          participant_id: context.participantId,
          role: context.role,
        },
        arguments: args,
      };
      return queuedToolResult(await store.enqueueCommand(context.sessionId, command));
    },
  );

  server.registerTool(
    "bgo_move_object_to_point",
    {
      title: "Move object to grid point",
      description: "Queues a validated request to move one object to a logical grid point.",
      inputSchema: {
        object_id: z.string().min(1),
        x: z.number().int().min(0),
        y: z.number().int().min(0),
        footprint_x: z.number().int().min(1).default(1),
        footprint_y: z.number().int().min(1).default(1),
        allow_overlap: z.boolean().default(false),
      },
      annotations: writeAnnotations,
    },
    async (args) => {
      if (context.role !== "host") return toolResult({ ok: false, reason: "host_required" });
      const command: McpCommand = {
        tool: "bgo_move_object_to_point",
        context: {
          session_id: context.sessionId,
          participant_id: context.participantId,
          role: context.role,
        },
        arguments: args,
      };
      return queuedToolResult(await store.enqueueCommand(context.sessionId, command));
    },
  );

  return server;
}
