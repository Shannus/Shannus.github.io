import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import { state } from "@pulumi/terraform";

// --- Read the FOUNDATIONAL layer's outputs straight from Terraform's remote state. ---
// This is the "pass Terraform variables cleanly into Pulumi" hand-off: the platform team
// owns the Terraform (VPC, RDS, API, OIDC); the app team consumes its outputs here.
const cfg = new pulumi.Config();
const tenant = cfg.require("tenant");
const environment = cfg.require("environment");
const productSuite = "portfolio";
const prefix = `${productSuite}-${tenant}-${environment}`;

const tf = new state.RemoteStateReference("foundation", {
  backendType: "s3",
  bucket: cfg.require("tfStateBucket"),
  key: cfg.require("tfStateKey"),
  region: aws.config.region!,
});

const apiBaseUrl = tf.getOutput("api_base_url");

// Same mandatory tag convention as the Terraform layer.
const tags = {
  ProductSuite: productSuite,
  Tenant: tenant,
  Environment: environment,
  ManagedBy: "pulumi",
};

// App-level resource: publish the API base URL as an SSM parameter the frontend/app team owns.
const frontendConfig = new aws.ssm.Parameter(`${prefix}-frontend-config`, {
  name: `/${productSuite}/${tenant}/${environment}/frontend-config`,
  type: "String",
  value: apiBaseUrl.apply((u) => JSON.stringify({ apiBaseUrl: u })),
  tags,
});

export const frontendConfigName = frontendConfig.name;
export const consumedApiBaseUrl = apiBaseUrl;
