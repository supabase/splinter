// Extension: splinter-canvas
// A starter canvas extension for the Splinter project
//
// This single-file skeleton is a starting point. For more complex canvases
// (multiple actions with non-trivial logic, shared state, a custom renderer,
// etc.) prefer splitting things out: move each action handler into its own
// function, extract `open`/`onClose` into helpers, and pull large units
// (renderer assets, schema definitions, shared utilities) into sibling files
// imported from this entry point. Keep extension.mjs focused on wiring.

import { createServer } from "node:http";
import { joinSession, createCanvas } from "@github/copilot-sdk/extension";

// One local HTTP server per open canvas instance. Each instance gets its own
// ephemeral port so multiple canvases (or multiple opens of the same canvas)
// don't collide. Replace this with your real renderer — point a static-file
// server, a Vite/Next dev server, or any framework you like at the same URL.
const servers = new Map();

function renderHtml(instanceId) {
    return `<!doctype html>
<html>
  <head><meta charset="utf-8" /><title>splinter-canvas</title></head>
  <body style="font-family: system-ui; padding: 1rem;">
    <h1>splinter-canvas</h1>
    <p>Hello from a local canvas server.</p>
    <p>Instance: <code>${instanceId}</code></p>
  </body>
</html>`;
}

async function startServer(instanceId) {
    const server = createServer((req, res) => {
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        res.end(renderHtml(instanceId));
    });
    // Port 0 = let the OS pick a free ephemeral port. Bind to loopback only.
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    const address = server.address();
    const port = typeof address === "object" && address ? address.port : 0;
    return { server, url: `http://127.0.0.1:${port}/` };
}

const session = await joinSession({
    canvases: [
        createCanvas({
            id: "splinter-canvas",
            displayName: "splinter-canvas",
            description: "Example canvas - replace with your implementation",
            // Optional JSON Schema describing the input passed to open():
            // inputSchema: { type: "object", properties: {} },
            actions: [
                {
                    name: "example_action",
                    description: "Example agent-callable action on this canvas",
                    // Optional JSON Schema for the action input:
                    // inputSchema: { type: "object", properties: {} },
                    handler: async (ctx) => {
                        return { ok: true, instanceId: ctx.instanceId };
                    },
                },
            ],
            // Called when the agent or host opens the canvas. We boot a local
            // HTTP server on an ephemeral port and hand its URL back to the
            // host so it can render the canvas. Re-opens with the same
            // instanceId reuse the existing server.
            open: async (ctx) => {
                let entry = servers.get(ctx.instanceId);
                if (!entry) {
                    entry = await startServer(ctx.instanceId);
                    servers.set(ctx.instanceId, entry);
                }
                return {
                    title: "splinter-canvas",
                    url: entry.url,
                };
            },
            // Tear the per-instance server down when the canvas is closed so
            // ports are not leaked across the lifetime of the extension.
            onClose: async (ctx) => {
                const entry = servers.get(ctx.instanceId);
                if (entry) {
                    servers.delete(ctx.instanceId);
                    await new Promise((resolve) => entry.server.close(() => resolve()));
                }
            },
        }),
    ],
});
