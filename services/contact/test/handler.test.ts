import { describe, it, expect } from "vitest";
import { validate, handler } from "../src/handler.js";

describe("validate()", () => {
  it("accepts a well-formed message", () => {
    const r = validate({ name: "Ada", email: "ada@example.com", message: "hello" });
    expect(r.ok).toBe(true);
  });
  it("rejects a missing name", () => {
    const r = validate({ email: "ada@example.com", message: "hi" });
    expect(r.ok).toBe(false);
  });
  it("rejects a bad email", () => {
    const r = validate({ name: "Ada", email: "not-an-email", message: "hi" });
    expect(r.ok).toBe(false);
  });
  it("rejects an over-long message", () => {
    const r = validate({ name: "Ada", email: "ada@example.com", message: "x".repeat(5000) });
    expect(r.ok).toBe(false);
  });
  it("rejects a non-object body", () => {
    expect(validate("nope").ok).toBe(false);
  });
});

// Handler branches that short-circuit before touching the database.
function evt(method: string, body?: string) {
  return { requestContext: { http: { method } }, body } as any;
}

describe("handler() pre-DB branches", () => {
  it("handles CORS preflight", async () => {
    const res: any = await handler(evt("OPTIONS"));
    expect(res.statusCode).toBe(204);
  });
  it("rejects non-POST methods", async () => {
    const res: any = await handler(evt("GET"));
    expect(res.statusCode).toBe(405);
  });
  it("rejects invalid JSON", async () => {
    const res: any = await handler(evt("POST", "{not json"));
    expect(res.statusCode).toBe(400);
  });
  it("rejects a valid-JSON but invalid payload", async () => {
    const res: any = await handler(evt("POST", JSON.stringify({ name: "" })));
    expect(res.statusCode).toBe(400);
  });
});
