import type { Plugin } from "@opencode-ai/plugin";
import { mkdirSync, renameSync, writeFileSync } from "fs";
import { homedir, tmpdir } from "os";
import { join } from "path";

const DIR = join(homedir(), ".codex", "pets");
const PATH = join(DIR, "deskpet-state.json");

type Kind = "idle" | "running" | "waiting" | "failed" | "review";

function writeState(state: Kind, extra: Record<string, unknown> = {}) {
  try {
    mkdirSync(DIR, { recursive: true });
    const payload = JSON.stringify({
      state,
      source: "opencode",
      updatedAt: Date.now() / 1000,
      ...extra,
    });
    const tmp = join(tmpdir(), `deskpet-state-${process.pid}.json`);
    writeFileSync(tmp, payload);
    renameSync(tmp, PATH);
  } catch {}
}

function eventType(event: unknown): string {
  if (!event || typeof event !== "object") return "";
  const rec = event as Record<string, unknown>;
  return String(rec.type ?? rec.event ?? "");
}

function eventProps(event: unknown): Record<string, unknown> {
  if (!event || typeof event !== "object") return {};
  const rec = event as Record<string, unknown>;
  if (rec.properties && typeof rec.properties === "object") {
    return rec.properties as Record<string, unknown>;
  }
  return rec;
}

export const DeskPetPlugin: Plugin = async () => {
  writeState("idle");
  return {
    event: async ({ event }) => {
      const type = eventType(event).toLowerCase();
      const props = eventProps(event);
      const status = String(props.status ?? props.state ?? "").toLowerCase();
      if (type.includes("permission.asked") || type.includes("permission.ask")) {
        writeState("waiting", { type });
        return;
      }
      if (type.includes("permission.replied") || type.includes("permission.reply")) {
        writeState("running", { type });
        return;
      }
      if (type.includes("session.error") || status.includes("error") || status.includes("fail")) {
        writeState("failed", { type, status });
        return;
      }
      if (type.includes("session.idle") || status === "idle" || status === "done") {
        writeState("review", { type, status });
        return;
      }
      if (
        type.includes("session.status") ||
        type.includes("message.updated") ||
        type.includes("message.part")
      ) {
        if (["busy", "working", "running", "pending", "in_progress"].some((s) => status.includes(s))) {
          writeState("running", { type, status });
        } else if (["idle", "completed", "done"].some((s) => status.includes(s))) {
          writeState("review", { type, status });
        }
      }
    },
    "chat.message": async () => {
      writeState("running");
    },
    "permission.ask": async () => {
      writeState("waiting");
    },
    "tool.execute.before": async (input) => {
      writeState("running", { tool: input.tool });
    },
    "tool.execute.after": async () => {
      writeState("running");
    },
  };
};
