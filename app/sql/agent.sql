-- =============================================================================
-- Qlik Cloud Native App - Cortex Agent (On-Demand Creation)
-- =============================================================================

CREATE OR REPLACE PROCEDURE tools.create_agent()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS $$
import json

def main(session):
    row = session.sql("SELECT value FROM internal.config WHERE key = 'qlik_tenant'").collect()
    if not row or not row[0][0]:
        return "ERROR: Qlik tenant not configured. Set it in the Configuration tab first."

    try:
        session.sql("SELECT 1 FROM internal.config LIMIT 1").collect()
    except Exception as e:
        return f"ERROR: Pre-check failed: {e}"

    spec = """models:
  orchestration: auto
instructions:
  response: "You are a Qlik Cloud management assistant. Provide concise, accurate answers about Qlik apps. Always return structured results."
  orchestration: "Use the available Qlik tools to answer questions about Qlik Cloud apps. Use qlik_list_apps to discover apps, qlik_get_app for details, and the other tools for app management operations."
tools:
  - tool_spec:
      type: generic
      name: qlik_list_apps
      description: "List all Qlik Cloud apps. Returns app IDs, names, and metadata."
      input_schema:
        type: object
        properties:
          limit_val:
            type: number
            description: "Maximum number of apps to return (default 20)"
  - tool_spec:
      type: generic
      name: qlik_get_app
      description: "Get detailed information about a specific Qlik Cloud app by its ID."
      input_schema:
        type: object
        properties:
          app_id:
            type: string
            description: "The Qlik app identifier (UUID)"
        required: [app_id]
  - tool_spec:
      type: generic
      name: qlik_create_app
      description: "Create a new Qlik Cloud app with a given name and optional description."
      input_schema:
        type: object
        properties:
          app_name:
            type: string
            description: "Name for the new app"
          description:
            type: string
            description: "Optional description for the new app"
        required: [app_name]
  - tool_spec:
      type: generic
      name: qlik_update_app
      description: "Update an existing Qlik Cloud app name and description."
      input_schema:
        type: object
        properties:
          app_id:
            type: string
            description: "The Qlik app identifier to update"
          app_name:
            type: string
            description: "New name for the app"
          description:
            type: string
            description: "New description for the app"
        required: [app_id, app_name]
  - tool_spec:
      type: generic
      name: qlik_delete_app
      description: "Delete a Qlik Cloud app by its ID. This action is irreversible."
      input_schema:
        type: object
        properties:
          app_id:
            type: string
            description: "The Qlik app identifier to delete"
        required: [app_id]
tool_resources:
  qlik_list_apps:
    identifier: tools.qlik_list_apps
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
  qlik_get_app:
    identifier: tools.qlik_get_app
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
  qlik_create_app:
    identifier: tools.qlik_create_app
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
  qlik_update_app:
    identifier: tools.qlik_update_app
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
  qlik_delete_app:
    identifier: tools.qlik_delete_app
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: ""
"""

    delim = chr(36) * 2
    create_sql = f"CREATE OR REPLACE AGENT tools.qlik_agent FROM SPECIFICATION {delim}{spec}{delim}"
    try:
        session.sql(create_sql).collect()
        session.sql("GRANT USAGE ON AGENT tools.qlik_agent TO APPLICATION ROLE app_public").collect()
        return "Agent created successfully"
    except Exception as e:
        return f"Agent creation failed: {e}"
$$;

GRANT USAGE ON PROCEDURE tools.create_agent() TO APPLICATION ROLE app_public;

CREATE OR REPLACE PROCEDURE tools.run_agent(prompt STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
DECLARE
    agent_fqn STRING;
    request_body STRING;
    response STRING;
BEGIN
    SELECT CURRENT_DATABASE() || '.TOOLS.QLIK_AGENT' INTO agent_fqn;
    request_body := '{"messages": [{"role": "user", "content": [{"type": "text", "text": "' || REPLACE(REPLACE(:prompt, '\\', '\\\\'), '"', '\\"') || '"}]}]}';
    SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(:agent_fqn, :request_body) INTO response;
    RETURN response;
END;

GRANT USAGE ON PROCEDURE tools.run_agent(STRING) TO APPLICATION ROLE app_public;
