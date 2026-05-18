# Qlik Cloud Native App for Snowflake Cortex Agents

A Snowflake Native App that wraps the Qlik Cloud Apps REST API as tools for a Cortex Agent. Users can manage Qlik apps (list, get, create, update, delete) through natural language via Snowflake Intelligence.

## Prerequisites

- **Snowflake CLI** (`snow`) installed. See https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
- A configured Snowflake CLI connection profile. List yours with:
  ```bash
  snow connection list
  ```

## Configuration

### 1. Makefile

Edit the `SNOWFLAKE_CONNECTION` variable in `Makefile` to match your CLI connection profile name:

```makefile
SNOWFLAKE_CONNECTION ?= MyConnectionName
```

### 2. snowflake.yml

Edit `snowflake.yml` to set your **role** and **warehouse** for deployment:

```yaml
entities:
  qlik_app_pkg:
    ...
    meta:
      role: YOUR_ROLE        # e.g. ACCOUNTADMIN or a custom role with CREATE APPLICATION PACKAGE
      warehouse: YOUR_WH     # warehouse used during deployment
  qlik_app:
    ...
    meta:
      role: YOUR_ROLE
      warehouse: YOUR_WH
```

## Deploy

```bash
make run
```

## Teardown

```bash
make teardown
```

## Adding More Qlik API Endpoints

This app only wraps a subset of the Qlik Cloud Apps REST API (list, get, create, update, delete). The full API reference is at https://qlik.dev/apis/rest/apps/.

To add a new endpoint, follow these three steps:

### 1. Add an internal procedure in `app/sql/apis.sql`

Create a SQL wrapper that calls the generic `_qlik_api_call` with the right method/path:

```sql
CREATE OR REPLACE PROCEDURE internal._qlik_export_app(app_id STRING)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_api_call('POST', '/api/v1/apps/' || :app_id || '/export', NULL, NULL) INTO result;
    RETURN result;
END;
```

### 2. Add a public proxy in `app/sql/proxies.sql`

The proxy is a thin wrapper in the `tools` schema that delegates to the internal proc and is granted to the app role:

```sql
CREATE OR REPLACE PROCEDURE tools.qlik_export_app(app_id STRING)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_export_app(:app_id) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_export_app(STRING) TO APPLICATION ROLE app_public;
```

### 3. Register as an agent tool in `app/sql/agent.sql`

Add the tool spec and tool resource in the agent's YAML specification inside `tools.create_agent()`:

```yaml
# Under tools:
  - tool_spec:
      type: generic
      name: qlik_export_app
      description: "Export a Qlik Cloud app to a downloadable file."
      input_schema:
        type: object
        properties:
          app_id:
            type: string
            description: "The Qlik app identifier to export"
        required: [app_id]

# Under tool_resources:
  qlik_export_app:
    identifier: tools.qlik_export_app
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
```

After adding all three, redeploy with `make run` and click **Create Agent** in the app UI to recreate the agent with the new tool.

## Project Structure

```
.
├── Makefile              # CLI shortcuts (run, teardown, logs)
├── snowflake.yml         # Snow CLI project definition
├── test_qlik_auth.py    # Local OAuth test script
└── app/
    ├── manifest.yml      # Native App manifest (references, streamlit)
    ├── README.md         # In-app documentation
    ├── streamlit/        # Streamlit UI (config + agent chat)
    │   ├── streamlit_app.py
    │   └── environment.yml
    └── sql/
        ├── init.sql      # Setup script
        ├── callbacks.sql # Reference callbacks + config
        ├── apis.sql      # Qlik API call procedures
        ├── proxies.sql   # Public proxy procedures
        └── agent.sql     # Agent creation + run procedures
```
