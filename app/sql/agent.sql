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

    spec = """models:
  orchestration: auto
instructions:
  response: "You are a Qlik Cloud assistant. Use the qlik_mcp_call tool to interact with Qlik Cloud. Always return clear, structured results."
  orchestration: "You have a single tool called qlik_mcp_call that connects to the Qlik Cloud MCP server. Available MCP tool names include: qlik_search, qlik_describe_app, qlik_get_fields, qlik_list_sheets, qlik_get_sheet_details, qlik_list_bookmarks, qlik_create_bookmark, qlik_select_bookmark, qlik_delete_bookmark, qlik_get_field_values, qlik_search_field_values, qlik_get_chart_data, qlik_get_chart_info, qlik_create_data_object, qlik_select_values, qlik_clear_selections, qlik_get_current_selections, qlik_create_sheet, qlik_add_chart, qlik_add_filter, qlik_list_dimensions, qlik_create_dimension, qlik_list_measures, qlik_create_measure, qlik_get_lineage, qlik_get_dataset, qlik_get_dataset_schema, qlik_get_dataset_sample. Pass the tool_name and arguments JSON string to qlik_mcp_call."
tools:
  - tool_spec:
      type: generic
      name: qlik_mcp_call
      description: "Call any tool on the Qlik Cloud MCP server. Pass the MCP tool name and its arguments as a JSON string."
      input_schema:
        type: object
        properties:
          tool_name:
            type: string
            description: "The MCP tool name to invoke (e.g. qlik_search, qlik_describe_app, qlik_get_fields, qlik_list_sheets)"
          arguments:
            type: string
            description: "JSON string of arguments for the tool"
        required: ["tool_name"]
tool_resources:
  qlik_mcp_call:
    identifier: tools.qlik_mcp_call
    type: procedure
    execution_environment:
      type: warehouse
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
