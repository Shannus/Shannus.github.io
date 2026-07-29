import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from "aws-lambda";
import { Client } from "pg";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

// Multi-tenant compliance context — injected by Terraform per [ProductSuite]-[TenantName]-[Environment].
const PRODUCT_SUITE = process.env.PRODUCT_SUITE ?? "portfolio";
const TENANT = process.env.TENANT ?? "public";
const ENVIRONMENT = process.env.ENVIRONMENT ?? "dev";

// Database access controls: creds are NEVER baked into the bundle or env in plaintext.
// The function fetches them from Secrets Manager at cold start using its execution role.
const DB_SECRET_ARN = process.env.DB_SECRET_ARN ?? "";
const DB_HOST = process.env.DB_HOST ?? "";
const DB_NAME = process.env.DB_NAME ?? "portfolio";

const sm = new SecretsManagerClient({});
let cachedCreds: { username: string; password: string } | null = null;

async function getCreds(): Promise<{ username: string; password: string }> {
  if (cachedCreds) return cachedCreds;
  const res = await sm.send(new GetSecretValueCommand({ SecretId: DB_SECRET_ARN }));
  const parsed = JSON.parse(res.SecretString ?? "{}");
  cachedCreds = { username: parsed.username, password: parsed.password };
  return cachedCreds;
}

function json(statusCode: number, body: unknown): APIGatewayProxyResultV2 {
  return {
    statusCode,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "POST,OPTIONS",
      "access-control-allow-headers": "content-type",
    },
    body: JSON.stringify(body),
  };
}

export interface ContactInput {
  name: string;
  email: string;
  message: string;
}

export type ValidationResult =
  | { ok: true; value: ContactInput }
  | { ok: false; error: string };

// Pure, dependency-free validator — the core of the unit-test (Build-Breaker) gate.
export function validate(input: unknown): ValidationResult {
  if (!input || typeof input !== "object") return { ok: false, error: "body must be a JSON object" };
  const o = input as Record<string, unknown>;
  const name = String(o.name ?? "").trim();
  const email = String(o.email ?? "").trim();
  const message = String(o.message ?? "").trim();
  if (name.length < 1 || name.length > 120) return { ok: false, error: "name is required (1-120 chars)" };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, error: "a valid email is required" };
  if (message.length < 1 || message.length > 4000) return { ok: false, error: "message is required (1-4000 chars)" };
  return { ok: true, value: { name, email, message } };
}

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {
  const method = event.requestContext?.http?.method ?? "POST";
  if (method === "OPTIONS") return json(204, {});
  if (method !== "POST") return json(405, { error: "method not allowed" });

  let parsed: unknown;
  try {
    parsed = event.body ? JSON.parse(event.body) : {};
  } catch {
    return json(400, { error: "invalid JSON body" });
  }

  const result = validate(parsed);
  if (!result.ok) return json(400, { error: result.error });

  const creds = await getCreds();
  const client = new Client({
    host: DB_HOST,
    database: DB_NAME,
    user: creds.username,
    password: creds.password,
    port: 5432,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
  });

  try {
    await client.connect();
    // Logical tenant isolation: each tenant owns a dedicated Postgres schema.
    await client.query(
      `INSERT INTO "${TENANT}".messages (name, email, message, product_suite, environment)
       VALUES ($1, $2, $3, $4, $5)`,
      [result.value.name, result.value.email, result.value.message, PRODUCT_SUITE, ENVIRONMENT],
    );
    return json(201, { status: "received" });
  } catch (err) {
    console.error("db_insert_failed", err);
    return json(500, { error: "could not store message" });
  } finally {
    await client.end().catch(() => {});
  }
};
