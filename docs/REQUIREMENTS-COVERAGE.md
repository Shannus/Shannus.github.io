# Requirements Coverage — Senior DevOps Engineer (Platform Automation)

Every line of the job description mapped to the file and mechanism that implements it.
Use this as your build checklist *and* your interview cheat sheet.

Naming convention used everywhere: **`[ProductSuite]-[TenantName]-[Environment]`** → `portfolio-public-dev`.
Two "product lines" model the JD's V1/V2 consolidation: **contact = V1** (in-VPC, DB-backed), **status = V2** (no DB).

---

## 1. Rapid Pipeline Modernization — the CI Gate

| Requirement | Where | How |
|---|---|---|
| Production-grade GitHub Actions workflows | `.github/workflows/ci.yml`, `deploy.yml`, `rollback.yml` | One CI/CD workflow + a reusable `deploy.yml` (`workflow_call`) + a dispatchable rollback. |
| Consolidate V1 **and** V2 product lines | `ci.yml` → `build-test` job `matrix.service: [contact, status]` | A single matrixed workflow builds/tests both lines instead of separate legacy pipelines. |
| GitHub-hosted runners, parallel + isolated | `runs-on: ubuntu-latest` + `strategy.matrix` (`fail-fast: false`) | Each product line runs on its own fresh managed VM, in parallel. |
| Build-Breaker: SonarQube | `ci.yml` → `sonarqube` job + `sonar-project.properties` | `sonarqube-scan-action` then `sonarqube-quality-gate-action` (`qualitygate.wait=true`) fails the PR. |
| Build-Breaker: unit tests (Jest/**Vitest**) | `ci.yml` step `npm test`; tests in `services/*/test/*.test.ts` | Vitest; 9 tests (contact) + 5 tests (status) — verified green. |
| Build-Breaker: vulnerability checks (`npm audit`) | `ci.yml` step `npm audit --audit-level=high` | Fails the build on high/critical advisories. |

## 2. Node.js Build & Dependency Lifecycle

| Requirement | Where | How |
|---|---|---|
| `package.json`, package locks, script orchestration | `services/*/package.json`, `package-lock.json` | Scripts: `typecheck`, `test`, `build`, `package`, `audit`. `npm ci` uses the lockfile. |
| Efficient build → lightweight Lambda bundle | `services/*/esbuild.mjs` | esbuild `--bundle --minify --target=node22`, externalizes `@aws-sdk/*` (provided by runtime). |
| Bundles sized for Lambda storage limits | verified artifacts | contact = **24 KB** zip, status = **876 B** zip (limit is 50 MB unzipped). |
| `npm audit` continuous scanning | `ci.yml` + `npm run audit` | Same gate locally and in CI. |
| `npm audit fix` / **`npm overrides`** | `services/contact/package.json` → `overrides` | Force-pins `pg-connection-string@2.7.0` (transitive). `npm ls` shows `overridden`; tests stay green — the supply-chain patch mechanism. |

## 3. Hybrid Infrastructure & Cloud Security — the IaC Strategy

| Requirement | Where | How |
|---|---|---|
| Terraform: AWS networking | `infra/modules/network` | VPC, 2 private subnets, route table, **no NAT** (cost-safe), Secrets Manager interface endpoint. |
| Terraform: security configurations | `infra/modules/network` (SGs) + `infra/modules/service` (scoped IAM) | Lambda→DB on 5432 only; least-privilege execution + deploy roles. |
| Terraform: database access controls | `infra/modules/database` | RDS private, encrypted; creds only in Secrets Manager; role-gated `GetSecretValue`. |
| **Pulumi (TypeScript)** consuming Terraform variables | `pulumi/index.ts` | `terraform.state.RemoteStateReference` reads TF S3 outputs → creates app-layer SSM param. The platform→app hand-off. |
| **AWS OIDC Federation, zero static keys** | `infra/modules/oidc` + `deploy.yml` | TF creates the GitHub OIDC provider + per-environment role scoped by `sub=repo:...:environment:<env>`. Workflow uses `id-token: write` + `configure-aws-credentials` (no `aws-access-key-id` anywhere). |

## 4. Release Automation & Storage — the CD Gate

| Requirement | Where | How |
|---|---|---|
| **Liquibase** schema migrations in the pipeline | `db/changelog/**` + `deploy.yml` "Run Liquibase migrations" | Master + 3 changesets (schema, table, index), each with preconditions + rollback; run via `liquibase/liquibase` container. |
| Dev → Stage → Prod routes | `ci.yml` → `deploy-dev` → `deploy-stage` → `deploy-prod` (`needs:` chain) | Sequential, each pinned to a GitHub Environment. |
| GitHub Environments + **manual reviewer approval** | `deploy.yml` `environment: ${{ inputs.environment }}`; prod = `production` | Required-reviewer protection rule on `production` (set in repo settings — see RUNBOOK). |
| Lambda **versioning** | `infra/modules/service` (`publish = true`) + `deploy.yml` (`--publish`) | Every deploy mints an immutable version. |
| Lambda **aliases** | `infra/modules/service` (`aws_lambda_alias.live`) | API Gateway targets the alias, not `$LATEST`. |
| GitHub Actions **Artifacts** → deployment history | `ci.yml` `upload-artifact` (`<service>-<sha>`) | Each build's zip is retained and traceable to a commit. |
| **1-second rollback** | `rollback.yml` + prod canary in `deploy.yml` | Rollback = one `update-alias` call to the previous version; deploys shift traffic 10% → 100%. |

## 5. Strict Multi-Tenant Compliance Tagging

| Requirement | Where | How |
|---|---|---|
| Mandatory `[ProductSuite]-[TenantName]-[Environment]` across all scripts | `infra/modules/naming` | Regex-validated inputs; `prefix` used for every resource name; enforced, not optional. |
| Compliance tags on every resource | `infra/main.tf` `provider "aws" { default_tags }` | `ProductSuite/Tenant/Environment/ManagedBy/Repo` auto-applied to all resources. Pulmi mirrors it. |
| Logical separation of resources **and Lambdas** | naming `prefix` per tenant; contact handler `"${TENANT}".messages` | Each tenant → own resource names + own Postgres schema. Add a tenant by re-applying with `-var tenant=<name>`. |

## Skills & Team Fit

| Item | Where |
|---|---|
| SonarQube (code scanner) | `sonar-project.properties` + `ci.yml` sonarqube job |
| Secure VPC networking | `infra/modules/network` (private subnets, SGs, VPC endpoint, no NAT) |
| Serverless: Lambda versions/aliases/traffic-shifting | `infra/modules/service` + `deploy.yml` |
| Clean YAML / infra scripts (execution focus) | `tofu fmt`-clean HCL; YAML-lint-clean workflows |

---

## Known real-world gap (say this in the interview, don't hide it)
Stage/prod RDS instances are **private**, so GitHub-hosted runners can't reach them for the
Liquibase step. The dev DB is set `publicly_accessible` so the pipeline runs end-to-end for
learning. The production-correct fix is to run migrations from a **self-hosted runner inside the
VPC** (Actions Runner Controller on EKS — which you already know) or an in-VPC CodeBuild step.
Naming this tradeoff unprompted is exactly the judgment the role is screening for.
