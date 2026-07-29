# Runbook — deploy the portfolio backend

You run these steps; the scaffold is ready. Everything uses your **personal** AWS account.
Nothing here commits a secret or an AWS key (OIDC = zero static keys).

## 0. Prerequisites
- AWS account + AWS CLI logged in (`aws sts get-caller-identity` works).
- Terraform ≥ 1.6 **or** OpenTofu ≥ 1.8 (`terraform` / `tofu` — commands below use `terraform`).
- `gh` CLI (optional, for setting env vars) and Node 22.
- A SonarQube Cloud account (free for public repos) → create an org + a project token.

## 1. Bootstrap remote state (one time)
```bash
aws s3 mb s3://<your-tfstate-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-tfstate-bucket> \
  --versioning-configuration Status=Enabled
```
Edit `infra/backend.tf` → set `bucket = "<your-tfstate-bucket>"`.
(First run only: you can comment out the whole `backend "s3"` block to use local state.)

## 2. First apply — dev (creates the OIDC provider)
```bash
cd infra
terraform init
terraform apply -var-file=envs/dev.tfvars    # dev.tfvars sets create_oidc_provider = true
```
For the dev learning DB to be reachable by GitHub-hosted runners during Liquibase, either:
- temporarily set the RDS `publicly_accessible = true` (dev only) and open the DB SG to the
  runner, **or**
- run the first `liquibase update` yourself from your laptop (see §6).

Save these outputs:
```bash
terraform output api_base_url
terraform output gha_deploy_role_arn
```

## 3. Stage + Prod infra
```bash
terraform apply -var-file=envs/stage.tfvars   # create_oidc_provider = false
terraform apply -var-file=envs/prod.tfvars     # create_oidc_provider = false
```
> Note: each env is a separate state if you use separate keys/workspaces. Simplest path for
> learning: one env at a time, `terraform destroy` between sessions (see §9). Grab each env's
> `gha_deploy_role_arn`.

## 4. GitHub Environments (the CD gate)
In the repo → **Settings → Environments**, create `dev`, `stage`, `production`.
- On **production**, add a **Required reviewers** rule (yourself) = the manual approval lock.
- For each environment add:
  - **Variable** `AWS_DEPLOY_ROLE_ARN` = that env's `gha_deploy_role_arn`
  - **Variable** `AWS_REGION` = `us-east-1`
- Repo-level **Secret** `SONAR_TOKEN` = your SonarQube Cloud token.

CLI shortcut per env:
```bash
gh variable set AWS_DEPLOY_ROLE_ARN --env dev --body "arn:aws:iam::<acct>:role/portfolio-public-dev-gha-deploy"
gh variable set AWS_REGION --env dev --body "us-east-1"
gh secret set SONAR_TOKEN --body "<token>"
```
Also set `sonar.organization` in `sonar-project.properties` to your SonarQube Cloud org key.

## 5. Push and watch the pipeline
```bash
git add . && git commit -m "add platform-automation backend" && git push origin main
```
- PR → the **Build-Breaker** gate runs (build/test/audit per service + Sonar quality gate).
- Push to main → `deploy-dev` → `deploy-stage` → `deploy-prod` (prod waits for your approval).

## 6. Run migrations manually (alternative to the pipeline step)
```bash
SECRET=$(aws secretsmanager get-secret-value --secret-id portfolio-public-dev/db --query SecretString --output text)
docker run --rm -v "$PWD/db:/liquibase/changelog" liquibase/liquibase:4.29 \
  --search-path=/liquibase/changelog --changeLogFile=changelog/db.changelog-master.xml \
  --url="jdbc:postgresql://$(echo $SECRET|jq -r .host):5432/$(echo $SECRET|jq -r .dbname)" \
  --username="$(echo $SECRET|jq -r .username)" --password="$(echo $SECRET|jq -r .password)" \
  -Dtenant=public update
```

## 7. Wire the frontend
1. Copy `assets/app.js` into your repo (already in this scaffold).
2. In `index.html`, just before `</body>`:
   ```html
   <meta name="api-base" content="PASTE_api_base_url_HERE">
   <script src="assets/app.js" defer></script>
   ```
   (the `<meta>` can also live in `<head>`.)
3. Make the hero status live — add hooks to an element you already have:
   ```html
   <span data-status-badge>…</span> <span data-version></span>
   ```
4. Add a contact form in your Contact section:
   ```html
   <form id="contact-form">
     <input name="name" placeholder="Name" required>
     <input name="email" type="email" placeholder="Email" required>
     <textarea name="message" placeholder="Message" required></textarea>
     <button type="submit">Send</button>
   </form>
   <p id="contact-result"></p>
   ```
`app.js` is defensive — if any hook is missing it simply does nothing.

## 8. Smoke test
```bash
curl "$(terraform output -raw status_endpoint)"
curl -X POST "$(terraform output -raw contact_endpoint)" \
  -H 'content-type: application/json' \
  -d '{"name":"Shanz","email":"me@example.com","message":"hello"}'
```

## 9. Rollback drill (the "1-second rollback")
GitHub → **Actions → rollback → Run workflow** → pick environment + service.
Leave version blank to fall back to the immediately previous version. It's a single
`update-alias` call, so it's effectively instant.

## 10. Teardown (do this between study sessions to stay ~free)
```bash
cd infra
terraform destroy -var-file=envs/dev.tfvars
# repeat for stage/prod if applied
```

## Cost notes
- No NAT gateway by design (would be ~$32/mo).
- `db.t4g.micro` + 20 GB gp3 is free-tier eligible for 12 months; destroy when idle.
- Lambda + HTTP API + Secrets Manager at this volume are pennies.
