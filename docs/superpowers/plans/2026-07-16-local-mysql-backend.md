# Local MySQL Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the existing TyreVibes Express API and its complete MySQL persistence locally while retaining hosted Supabase authentication and supporting both the iOS Simulator and an iPhone on the Mac's LAN.

**Architecture:** The iOS client keeps using hosted Supabase for authentication and sends its Supabase bearer token to the existing Express API. Express listens on all Mac interfaces, verifies the token with the configured Supabase JWT secret, and persists API-owned data in local MySQL. A single local hostname in `Api.plist` supplies all REST endpoints.

**Tech Stack:** Node.js 22, Express, mysql2, jsonwebtoken, Sharp, MySQL 9/Homebrew, Swift, XCTest, shell scripts.

---

## File structure

- `package.json`: exact Node runtime, dependency, test, and schema-validation commands.
- `package-lock.json`: reproducible Node dependencies.
- `.env.local.example`: documented non-secret backend configuration.
- `database/schema_server_mysql.sql`: authoritative MySQL schema for tables referenced by `server.js`.
- `tests/backend/schema-contract.test.mjs`: static contract checks between the server and schema.
- `tests/backend/config.test.mjs`: backend configuration and listener regression tests.
- `scripts/local-backend-env.sh`: derives the Mac Bonjour/LAN address and exports local API settings.
- `scripts/setup-local-mysql.sh`: creates the empty database and applies the authoritative schema.
- `scripts/run-local-backend.sh`: loads local secrets and starts Express.
- `TyreVibes/Api.plist`: points REST traffic to the Mac while preserving hosted Supabase values.
- `TyreVibes/Info.plist`: permits HTTP only for local networking.
- `server.js`: validates configuration, supports `DB_PORT` and `HOST`, and reports real DB health.

### Task 1: Lock the server-to-schema contract

**Files:**
- Create: `tests/backend/schema-contract.test.mjs`
- Create: `database/schema_server_mysql.sql`

- [ ] **Step 1: Write the failing schema contract test**

```js
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const schema = readFileSync(new URL("../../database/schema_server_mysql.sql", import.meta.url), "utf8");
const requiredTables = [
  "users", "vehicles", "plates", "user_vehicles", "vehicle_images",
  "plate_insurance", "vehicle_revisions", "vehicle_tyres_supported",
  "tyres_vehicles", "tyre_analyses", "tread_depth_measurements",
  "tyre_lifecycle_projections", "tyre_recommendations", "image_uploads",
  "maintenance_entries", "maintenance_attachments", "user_profiles",
  "user_profile_images", "user_settings", "bug_reports", "user_analysis_stats"
];

test("the local schema defines every concrete API table", () => {
  for (const table of new Set(requiredTables)) {
    assert.match(schema, new RegExp(`CREATE\\s+(?:OR\\s+REPLACE\\s+VIEW|TABLE\\s+IF\\s+NOT\\s+EXISTS)\\s+${table}\\b`, "i"), table);
  }
});

test("server-specific vehicle columns are present", () => {
  for (const column of ["model_detail", "make", "fuel_type", "displacement_cc", "power_cv", "power_kw", "current_mileage"]) {
    assert.match(schema, new RegExp(`\\b${column}\\b`, "i"), column);
  }
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test tests/backend/schema-contract.test.mjs`

Expected: FAIL because `database/schema_server_mysql.sql` does not exist.

- [ ] **Step 3: Add the authoritative schema**

Create complete idempotent DDL for the existing tables used by `server.js`: `users`, `vehicles`, `plates`, `user_vehicles`, `vehicle_images`, `plate_insurance`, `vehicle_revisions`, `vehicle_tyres_supported`, `tyres_vehicles`, `tyre_analyses`, `tread_depth_measurements`, `tyre_lifecycle_projections`, `tyre_recommendations`, `image_uploads`, `maintenance_entries`, `maintenance_attachments`, `user_profiles`, `user_profile_images`, `user_settings`, and `bug_reports`. Define `user_analysis_stats` as a view grouped from `tyre_analyses` using the existing response fields:

```sql
CREATE OR REPLACE VIEW user_analysis_stats AS
SELECT user_id,
       COUNT(*) AS total_analyses,
       COUNT(DISTINCT tyre_id) AS tyres_analyzed,
       AVG(depth_average) AS avg_depth,
       AVG(remaining_life_percentage) AS avg_remaining_life,
       MAX(analysis_date) AS last_analysis_date
FROM tyre_analyses
GROUP BY user_id;
```

Use the column names and types already consumed by the SQL statements in `server.js`; UUID user references remain `VARCHAR(128)` and must not depend on a local users row because Supabase owns authentication.

- [ ] **Step 4: Run the contract tests**

Run: `node --test tests/backend/schema-contract.test.mjs`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add database/schema_server_mysql.sql tests/backend/schema-contract.test.mjs
git commit -m "feat: add local MySQL API schema"
```

### Task 2: Make the existing Express server locally runnable

**Files:**
- Create: `package.json`
- Create: `package-lock.json`
- Create: `.env.local.example`
- Create: `tests/backend/config.test.mjs`
- Modify: `server.js`

- [ ] **Step 1: Write failing configuration assertions**

```js
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("../../server.js", import.meta.url), "utf8");

test("MySQL accepts an explicit local port", () => {
  assert.match(source, /port:\s*Number\(process\.env\.DB_PORT\s*\|\|\s*3306\)/);
});

test("Express explicitly listens on the LAN host", () => {
  assert.match(source, /const HOST = process\.env\.HOST \|\| "0\.0\.0\.0"/);
  assert.match(source, /app\.listen\(PORT, HOST,/);
});

test("health checks execute a database query", () => {
  assert.match(source, /await pool\.query\("SELECT 1 AS ok"\)/);
});
```

- [ ] **Step 2: Verify the tests fail**

Run: `node --test tests/backend/config.test.mjs`

Expected: FAIL for missing port, host, and database query.

- [ ] **Step 3: Add runtime metadata**

```json
{
  "name": "tyrevibes-local-backend",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "test:backend": "node --test tests/backend/*.test.mjs"
  },
  "engines": { "node": ">=22" },
  "dependencies": {
    "express": "^5.1.0",
    "jsonwebtoken": "^9.0.2",
    "mysql2": "^3.14.3",
    "sharp": "^0.34.3"
  }
}
```

Run: `npm install`

Expected: dependencies install and `package-lock.json` is created.

- [ ] **Step 4: Add explicit local configuration**

Add `port: Number(process.env.DB_PORT || 3306)` to the MySQL pool. Replace the health handler's pool-internal-only assumption with `await pool.query("SELECT 1 AS ok")` before building its response. Start with:

```js
const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "0.0.0.0";
app.listen(PORT, HOST, () => {
  console.log(`TyreVibes API disponibile su http://${HOST}:${PORT}`);
});
```

Create the non-secret template:

```dotenv
HOST=0.0.0.0
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=tyrevibes
DB_PASS=change-me
DB_NAME=tyrevibes
SUPABASE_JWT_SECRET=paste-hosted-project-jwt-secret
SECNEO_ENABLED=false
```

- [ ] **Step 5: Run backend tests**

Run: `npm run test:backend`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json .env.local.example server.js tests/backend/config.test.mjs
git commit -m "feat: make Express backend runnable on LAN"
```

### Task 3: Add repeatable MySQL setup and backend launch

**Files:**
- Create: `scripts/setup-local-mysql.sh`
- Create: `scripts/run-local-backend.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Add a shell syntax test to the backend test command**

Add a Node test that executes `bash -n scripts/setup-local-mysql.sh` and `bash -n scripts/run-local-backend.sh`, asserting exit status zero. Run it before the scripts exist and expect FAIL.

- [ ] **Step 2: Implement idempotent database setup**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.local"
[[ -f "${ENV_FILE}" ]] || { echo "Manca ${ENV_FILE}; copialo da .env.local.example."; exit 1; }
set -a
source "${ENV_FILE}"
set +a
: "${DB_USER:?DB_USER mancante}"
: "${DB_PASS:?DB_PASS mancante}"
: "${DB_NAME:?DB_NAME mancante}"
mysql -h "${DB_HOST:-127.0.0.1}" -P "${DB_PORT:-3306}" -u root +  -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
      GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
      FLUSH PRIVILEGES;"
mysql -h "${DB_HOST:-127.0.0.1}" -P "${DB_PORT:-3306}" -u "${DB_USER}" "-p${DB_PASS}" "${DB_NAME}" +  < "${ROOT_DIR}/database/schema_server_mysql.sql"
```

- [ ] **Step 3: Implement backend launch**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${ROOT_DIR}/.env.local" ]] || { echo "Manca .env.local."; exit 1; }
set -a
source "${ROOT_DIR}/.env.local"
set +a
cd "${ROOT_DIR}"
exec npm start
```

Add `.env.local` to `.gitignore`, make both scripts executable, run the syntax tests, and expect PASS.

- [ ] **Step 4: Commit**

```bash
git add .gitignore scripts/setup-local-mysql.sh scripts/run-local-backend.sh tests/backend/scripts.test.mjs
git commit -m "feat: automate local MySQL backend setup"
```

### Task 4: Route iOS REST calls to the Mac without exposing internals

**Files:**
- Create: `scripts/configure-local-api.sh`
- Modify: `TyreVibes/Api.plist`
- Modify: `TyreVibes/Info.plist`
- Create: `tests/backend/ios-config.test.mjs`

- [ ] **Step 1: Write failing iOS configuration tests**

The test loads both plists with `plutil -convert json -o -` and asserts:

```js
assert.equal(api.BASE_URL, `http://${api.LOCAL_BACKEND_HOST}:3000/api`);
assert.equal(api.SavePlateURL, `${api.BASE_URL}/v1/save_plate`);
assert.equal(api.ManualPlateURL, `${api.BASE_URL}/v1/manual_plate`);
assert.equal(api.CheckPlateBaseURL, `${api.BASE_URL}/v1/check_plate`);
assert.equal(info.NSAppTransportSecurity.NSAllowsLocalNetworking, true);
assert.equal(api.SUPABASE_URL, "https://jbcbrnegmqraivdfmlsn.supabase.co");
```

Run: `node --test tests/backend/ios-config.test.mjs`

Expected: FAIL because REST URLs still target the retired hosting.

- [ ] **Step 2: Implement stable Bonjour configuration**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="${ROOT_DIR}/TyreVibes/Api.plist"
HOST_NAME="$(scutil --get LocalHostName).local"
BASE_URL="http://${HOST_NAME}:3000/api"
set_key() {
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "${PLIST}" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$1 string $2" "${PLIST}"
}
set_key LOCAL_BACKEND_HOST "${HOST_NAME}"
set_key BASE_URL "${BASE_URL}"
set_key ManualPlateURL "${BASE_URL}/v1/manual_plate"
set_key SavePlateURL "${BASE_URL}/v1/save_plate"
set_key CheckPlateBaseURL "${BASE_URL}/v1/check_plate"
set_key GetAllCars "${BASE_URL}/v1/vehicles/:userId"
echo "Backend iOS configurato su ${BASE_URL}"
```

Run the script, add `NSAllowsLocalNetworking = true`, retain the existing localhost exception, and do not alter `SUPABASE_URL` or `SUPABASE_KEY`.

- [ ] **Step 3: Verify configuration**

Run: `node --test tests/backend/ios-config.test.mjs`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/configure-local-api.sh TyreVibes/Api.plist TyreVibes/Info.plist tests/backend/ios-config.test.mjs
git commit -m "feat: route iOS API traffic to local Mac"
```

### Task 5: Install and validate local MySQL

**Files:**
- Create locally, ignored: `.env.local`

- [ ] **Step 1: Install and start MySQL**

Run:

```bash
brew list mysql >/dev/null 2>&1 || brew install mysql
brew services start mysql
```

Expected: MySQL service reports `Successfully started mysql` or is already running.

- [ ] **Step 2: Create local configuration**

Copy `.env.local.example` to ignored `.env.local`, generate a random local MySQL password with `openssl rand -hex 24`, and leave `SUPABASE_JWT_SECRET` for the real hosted Supabase JWT secret. Never print or commit either secret.

- [ ] **Step 3: Initialize and inspect schema**

Run:

```bash
scripts/setup-local-mysql.sh
mysql -h 127.0.0.1 -u tyrevibes -p tyrevibes -e "SHOW FULL TABLES;"
```

Expected: all API tables and `user_analysis_stats` are listed.

- [ ] **Step 4: Start and probe Express**

Run `scripts/run-local-backend.sh`, then:

```bash
curl --fail http://127.0.0.1:3000/api/v1/health
curl --fail "http://$(scutil --get LocalHostName).local:3000/api/v1/health"
```

Expected: both return JSON with `"status":"healthy"`.

### Task 6: End-to-end verification

**Files:**
- Modify only if failures identify a defect in files already listed above.

- [ ] **Step 1: Run all backend tests**

Run: `npm run test:backend`

Expected: PASS.

- [ ] **Step 2: Build the iOS app**

Run the repository's existing simulator build command discovered from the Xcode project:

```bash
xcodebuild -project TyreVibes.xcodeproj -scheme TyreVibes -sdk iphonesimulator -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify authenticated API flow**

After hosted Supabase is active and `.env.local` contains its real JWT secret, sign up a fresh account in the app. Verify the health endpoint, save `FN841WA`, reload the garage, then exercise profile, tyre, analysis, settings, and maintenance persistence. Expected: no request targets `www.tyrevibes.com`, all authenticated routes return 2xx, and data survives app relaunch.

- [ ] **Step 4: Verify the physical iPhone**

With the Mac and iPhone on the same Wi-Fi, open `http://<Mac-LocalHostName>.local:3000/api/v1/health` from the iPhone browser, then repeat save/reload in the app. Expected: both succeed.

- [ ] **Step 5: Refresh Graphify and inspect the worktree**

Run:

```bash
graphify update .
git status --short
```

Expected: Graphify completes; only intended backend/configuration files plus the user's pre-existing work remain changed.
