import { describe, it, expect } from "vitest";
import { buildStatus, handler } from "../src/handler.js";

describe("buildStatus()", () => {
  it("reports operational when all components are healthy", () => {
    const s = buildStatus(new Date("2026-01-01T00:00:00.000Z"));
    expect(s.status).toBe("operational");
  });
  it("lists the four platform components", () => {
    expect(buildStatus().components).toHaveLength(4);
  });
  it("emits an ISO-8601 timestamp", () => {
    const s = buildStatus(new Date("2026-01-01T00:00:00.000Z"));
    expect(s.timestamp).toBe("2026-01-01T00:00:00.000Z");
  });
  it("echoes the tenancy context", () => {
    const s = buildStatus();
    expect(s.productSuite).toBeTypeOf("string");
    expect(s.tenant).toBeTypeOf("string");
    expect(s.environment).toBeTypeOf("string");
  });
});

describe("handler()", () => {
  it("returns 200 with a JSON body", async () => {
    const res: any = await handler({} as any);
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.status).toBe("operational");
  });
});
