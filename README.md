# Qlik Cloud Native App for Snowflake Cortex Agents

A Snowflake Native App that connects to the **Qlik Cloud MCP server** and exposes all Qlik MCP tools (59+) to a **Cortex Agent**. Users interact with Qlik Cloud through natural language via Snowflake Intelligence.

## How It Works

The app uses a single stored procedure (`internal._mcp_call`) that:

1. Authenticates to Qlik Cloud via **OAuth2 client credentials**
2. Calls the **Qlik MCP server** (`https://<tenant>/api/ai/mcp`) using JSON-RPC
3. Handles the MCP protocol (initialize session, then tools/call)

The Cortex Agent has one generic tool (`qlik_mcp_call`) that can invoke any of the 59+ Qlik MCP tools by name (e.g., `qlik_search`, `qlik_describe_app`, `qlik_get_fields`, `qlik_create_sheet`, etc.).

## Prerequisites

- **Snowflake CLI** (`snow`) installed. See https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
- A configured Snowflake CLI connection profile. List yours with:
  ```bash
  snow connection list
  ```
- A **Qlik Cloud OAuth2 client** (client ID + client secret) with MCP access

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

## App Setup (Post-Install)

Once the app is installed, open the Streamlit UI and follow:

1. **Enter your Qlik tenant hostname** (e.g. `mytenant.us.qlikcloud.com`) and click **Connect** to save it and approve the external access integration.
2. **Click "Create Agent"** to bind the procedures and create the Cortex Agent.

> **IMPORTANT: An account admin must run:**
> ```sql
> GRANT CALLER USAGE ON WAREHOUSE <my_warehouse> TO APPLICATION QLIK_APP;
> ```

## Available Qlik MCP Tools

The agent can call any of the 59+ tools on the Qlik MCP server, including:

| Category | Tools |
|----------|-------|
| App Discovery | `qlik_search`, `qlik_describe_app`, `qlik_get_fields`, `qlik_list_sheets` |
| Data Exploration | `qlik_get_field_values`, `qlik_search_field_values`, `qlik_get_chart_data`, `qlik_create_data_object` |
| Selections | `qlik_select_values`, `qlik_clear_selections`, `qlik_get_current_selections` |
| Visualization | `qlik_create_sheet`, `qlik_add_chart`, `qlik_add_filter` |
| Bookmarks | `qlik_list_bookmarks`, `qlik_create_bookmark`, `qlik_select_bookmark` |
| Master Items | `qlik_list_dimensions`, `qlik_create_dimension`, `qlik_list_measures`, `qlik_create_measure` |
| Datasets | `qlik_get_dataset`, `qlik_get_dataset_schema`, `qlik_get_dataset_sample` |
| Lineage | `qlik_get_lineage` |
| Glossary | `qlik_create_glossary`, `qlik_create_glossary_term`, `qlik_search_glossary_terms` |
| Data Products | `qlik_create_data_product`, `qlik_get_data_product` |

Full list: https://help.qlik.com/en-US/cloud-services/Subsystems/Hub/Content/Sense_Hub/QlikMCP/Qlik-MCP-server-tools.htm

## Project Structure

```
.
├── Makefile              # CLI shortcuts (run, teardown, logs)
├── snowflake.yml         # Snow CLI project definition
├── test_qlik_auth.py     # Local OAuth test script
├── test_qlik_mcp.py      # Local MCP connection test script
└── app/
    ├── manifest.yml      # Native App manifest (references, streamlit)
    ├── README.md         # In-app documentation
    ├── streamlit/        # Streamlit UI (config + agent chat)
    │   ├── streamlit_app.py
    │   └── environment.yml
    └── sql/
        ├── init.sql      # Setup script
        ├── callbacks.sql  # Reference callbacks + tenant config
        ├── apis.sql       # Single _mcp_call procedure (OAuth + MCP JSON-RPC)
        ├── proxies.sql    # Public proxy: tools.qlik_mcp_call
        └── agent.sql      # Agent creation + run procedures
```
