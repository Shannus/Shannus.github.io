import { build } from "esbuild";

// Produce a single minified CommonJS bundle sized for AWS Lambda.
// @aws-sdk/* is provided by the nodejs22.x runtime, so we externalize it
// to keep the deployment artifact small (JD: "optimized for Lambda storage limits").
await build({
  entryPoints: ["src/handler.ts"],
  bundle: true,
  minify: true,
  platform: "node",
  target: "node22",
  format: "cjs",
  outfile: "dist/index.js",
  external: ["@aws-sdk/*"],
  legalComments: "none",
});
console.log("built dist/index.js");
