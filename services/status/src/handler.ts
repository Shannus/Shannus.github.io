import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from "aws-lambda";

// Multi-tenant compliance context injected by Terraform: [ProductSuite]-[TenantName]-[Environment].
const PRODUCT_SUITE = process.env.PRODUCT_SUITE ?? "portfolio";
const TENANT = process.env.TENANT ?? "public";
const ENVIRONMENT = process.env.ENVIRONMENT ?? "dev";
// APP_VERSION is stamped at deploy time from the git SHA so /status reports exactly
// which Lambda version is live behind the alias.
const APP_VERSION = process.env.APP_VERSION ?? "0.0.0-local";

export interface Component {
  name: string;
  state: "operational" | "degraded" | "down";
}

export interface StatusResponse {
  status: "operational" | "degraded" | "down";
  productSuite: string;
  tenant: string;
  environment: string;
  version: string;
  components: Component[];
  timestamp: string;
}

// Pure builder — the unit-test target for the Build-Breaker gate.
export function buildStatus(now: Date = new Date()): StatusResponse {
  const components: Component[] = [
    { name: "Kubernetes & AWS EKS", state: "operational" },
    { name: "GitOps / ArgoCD", state: "operational" },
    { name: "Observability Stack", state: "operational" },
    { name: "Identity & Access", state: "operational" },
  ];
  const worst = components.some((c) => c.state === "down")
    ? "down"
    : components.some((c) => c.state === "degraded")
      ? "degraded"
      : "operational";
  return {
    status: worst,
    productSuite: PRODUCT_SUITE,
    tenant: TENANT,
    environment: ENVIRONMENT,
    version: APP_VERSION,
    components,
    timestamp: now.toISOString(),
  };
}

export const handler = async (_event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => ({
  statusCode: 200,
  headers: {
    "content-type": "application/json",
    "access-control-allow-origin": "*",
    "cache-control": "no-store",
  },
  body: JSON.stringify(buildStatus()),
});
