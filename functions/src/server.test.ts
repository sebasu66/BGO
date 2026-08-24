import assert from "node:assert/strict";
import test from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createBgoMcpServer, type BgoMcpContext } from "./server.js";
import type { BgoSessionStore, CommandResult, JsonObject, McpCommand } from "./store.js";
import { BGO_DEV_ALLOWED_HOSTS } from "./deployment.js";

class FakeStore implements BgoSessionStore {
  commands: McpCommand[] = [];

  async getSession(): Promise<JsonObject> {
    return {
      metadata: { definition_id: "test001" },
      mcp_commands: { private_command: { status: "pending" } },
      pieces: {
        miniature_1: {
          component_id: "bgo.piece.basic_cylinder",
          owner_id: "player_1",
          holder_id: "",
          quantity: 1,
          cell: { x: 5, y: 2 },
          footprint: { x: 2, y: 1 },
          location: { type: "grid" },
        },
        hidden_hand_piece: {
          component_id: "bgo.card.basic",
          owner_id: "player_2",
          holder_id: "player_2",
          visibility: "owner_only",
          location: { type: "hand", player_id: "player_2" },
        },
      },
    };
  }

  async getDefinition(): Promise<JsonObject> {
    return {
      game: { id: "test001" },
      table: {
        instances: [
          {
            component: "bgo.board.checkered",
            config: { columns: 8, rows: 6, grid_cell_size_cm: 5 },
          },
        ],
      },
      sandbox: { enabled: true },
    };
  }

  async enqueueCommand(_sessionId: string, command: McpCommand): Promise<CommandResult> {
    this.commands.push(command);
    return { command_id: "test-command", status: "completed", result: { ok: true } };
  }
}

async function connectedClient(context: BgoMcpContext, store: FakeStore) {
  const server = createBgoMcpServer(store, context);
  const client = new Client({ name: "bgo-test-client", version: "0.1.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  return { client, server };
}

const hostContext: BgoMcpContext = {
  environment: "dev",
  sessionId: "TEST001",
  participantId: "host",
  role: "host",
};

test("allows the official Firebase Function hostname", () => {
  assert.ok(
    BGO_DEV_ALLOWED_HOSTS.includes(
      "us-central1-board-game-online-68c3f.cloudfunctions.net",
    ),
  );
  assert.ok(BGO_DEV_ALLOWED_HOSTS.includes("bgomcpdev-j573jc222a-uc.a.run.app"));
});

test("advertises focused BGO tools and reads logical grid state", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(hostContext, store);
  try {
    const tools = await client.listTools();
    assert.deepEqual(
      tools.tools.map((tool) => tool.name).sort(),
      [
        "bgo_create_object_at_point",
        "bgo_execute",
        "bgo_get_context",
        "bgo_get_definition",
        "bgo_get_entities",
        "bgo_get_grid_state",
        "bgo_get_properties",
        "bgo_get_state",
        "bgo_inspect_object",
        "bgo_move_object_to_point",
        "bgo_objects_at_point",
        "bgo_set_properties",
      ],
    );
    const result = await client.callTool({ name: "bgo_objects_at_point", arguments: { x: 5, y: 2 } });
    assert.equal((result.structuredContent as JsonObject).ok, true);
    assert.deepEqual((result.structuredContent as JsonObject).object_ids, ["miniature_1"]);
    const footprintResult = await client.callTool({
      name: "bgo_objects_at_point",
      arguments: { x: 6, y: 2 },
    });
    assert.deepEqual((footprintResult.structuredContent as JsonObject).object_ids, ["miniature_1"]);
    const gridResult = await client.callTool({ name: "bgo_get_grid_state", arguments: {} });
    assert.deepEqual((gridResult.structuredContent as JsonObject).grid, {
      point_columns: 8,
      point_rows: 6,
      point_spacing_cm: { x: 5, y: 5 },
    });
  } finally {
    await client.close();
    await server.close();
  }
});

test("discovers entities and exposes an intentional property schema", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(hostContext, store);
  try {
    const listed = await client.callTool({ name: "bgo_get_entities", arguments: {} });
    const entities = (listed.structuredContent as JsonObject).entities as JsonObject[];
    assert.ok(entities.some((item) => item.entity === "Match.objects.miniature_1"));
    assert.ok(entities.some((item) => item.entity === "System.api"));
    const result = await client.callTool({
      name: "bgo_get_properties",
      arguments: { entity: "Match.objects.miniature_1" },
    });
    const content = result.structuredContent as JsonObject;
    assert.equal((content.properties as JsonObject).ownerId, "player_1");
    assert.equal(((content.schema as JsonObject).ownerId as JsonObject).writable, true);
    assert.deepEqual(content.commands, ["moveToPoint", "changeOwner"]);
  } finally {
    await client.close();
    await server.close();
  }
});

test("queues generic property changes and declared commands", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(hostContext, store);
  try {
    await client.callTool({
      name: "bgo_set_properties",
      arguments: {
        entity: "Match.objects.miniature_1",
        changes: { visibility: "owner_only" },
      },
    });
    await client.callTool({
      name: "bgo_execute",
      arguments: {
        entity: "Match.objects.miniature_1",
        command: "moveToPoint",
        arguments: { x: 2, y: 3 },
      },
    });
    assert.deepEqual(store.commands.map((command) => command.tool), [
      "bgo_set_properties",
      "bgo_execute",
    ]);
  } finally {
    await client.close();
    await server.close();
  }
});

test("generic mutation rejects undeclared properties and commands before enqueue", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(hostContext, store);
  try {
    const setResult = await client.callTool({
      name: "bgo_set_properties",
      arguments: { entity: "Match.objects.miniature_1", changes: { rawNodePath: "/root" } },
    });
    assert.equal((setResult.structuredContent as JsonObject).ok, false);
    const executeResult = await client.callTool({
      name: "bgo_execute",
      arguments: { entity: "Game.definition", command: "changeOwner", arguments: {} },
    });
    assert.equal((executeResult.structuredContent as JsonObject).ok, false);
    assert.equal(store.commands.length, 0);
  } finally {
    await client.close();
    await server.close();
  }
});

test("queues host sandbox mutations without writing game state", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(hostContext, store);
  try {
    const result = await client.callTool({
      name: "bgo_create_object_at_point",
      arguments: { catalog_id: "basic-miniature", object_id: "new-mini", x: 3, y: 4 },
    });
    assert.equal((result.structuredContent as JsonObject).ok, true);
    assert.equal(store.commands.length, 1);
    assert.equal(store.commands[0].tool, "bgo_create_object_at_point");
    assert.equal(store.commands[0].context.participant_id, "host");
  } finally {
    await client.close();
    await server.close();
  }
});

test("rejects host-only creation for a player context", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(
    { ...hostContext, participantId: "player_1", role: "player" },
    store,
  );
  try {
    const result = await client.callTool({
      name: "bgo_create_object_at_point",
      arguments: { catalog_id: "basic-miniature", object_id: "new-mini", x: 3, y: 4 },
    });
    assert.equal((result.structuredContent as JsonObject).ok, false);
    assert.equal(store.commands.length, 0);
  } finally {
    await client.close();
    await server.close();
  }
});

test("filters transport internals and another player's private hand", async () => {
  const store = new FakeStore();
  const { client, server } = await connectedClient(
    { ...hostContext, participantId: "player_1", role: "player" },
    store,
  );
  try {
    const result = await client.callTool({ name: "bgo_get_state", arguments: {} });
    const state = (result.structuredContent as JsonObject).state as JsonObject;
    assert.equal(state.mcp_commands, undefined);
    assert.equal((state.pieces as JsonObject).hidden_hand_piece, undefined);
    assert.ok((state.pieces as JsonObject).miniature_1);
  } finally {
    await client.close();
    await server.close();
  }
});
