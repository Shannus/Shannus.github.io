# Portfolio — Platform Automation backend

A production-patterned serverless backend bolted onto a static GitHub Pages portfolio.

- **Two product lines:** `contact` (V1 — API Gateway → Lambda → Postgres) and `status` (V2 — Lambda, no DB).
- **CI Gate:** GitHub Actions matrix build/test (`vitest`) + `npm audit` + SonarQube quality gate.
- **CD Gate:** Liquibase migrations → Dev→Stage→Prod GitHub Environments → Lambda versions/aliases with canary traffic shift + 1-second rollback.
- **IaC:** Terraform (VPC, RDS, IAM, API Gateway, GitHub OIDC — zero static keys); optional Pulumi app layer consuming TF outputs.
- **Multi-tenant:** every resource named/tagged `[ProductSuite]-[Tenant]-[Environment]`; per-tenant Postgres schema.

## Layout
```
services/contact   V1 Lambda (TypeScript, esbuild, vitest)
services/status    V2 Lambda (TypeScript, esbuild, vitest)
db/                Liquibase changelog (schema/table/index, with rollbacks)
infra/             Terraform (modules: naming, network, database, oidc, service)
pulumi/            Optional Pulumi (TS) app layer over Terraform state
.github/workflows  ci.yml (gate + deploy chain), deploy.yml (reusable), rollback.yml
assets/app.js      Front-end wiring (live status widget + contact form)
docs/              REQUIREMENTS-COVERAGE.md, RUNBOOK.md
```

## Start here
1. `docs/REQUIREMENTS-COVERAGE.md` — every JD line mapped to a file + mechanism.
2. `docs/RUNBOOK.md` — deploy it on your own AWS account, step by step.

## Verified locally
- contact: typecheck clean, 9 vitest tests pass, 24 KB deployment zip.
- status: typecheck clean, 5 vitest tests pass, 876 B deployment zip.
- Terraform: `tofu fmt` parse-clean across all modules.
- Workflows: YAML-valid.
