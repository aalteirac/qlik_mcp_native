-- =============================================================================
-- Qlik Cloud Native App - Public Proxy Procedures
-- =============================================================================

CREATE OR REPLACE PROCEDURE tools.qlik_mcp_call(
    tool_name STRING,
    arguments STRING DEFAULT '{}'
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._mcp_call(:tool_name, :arguments) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_mcp_call(STRING, STRING) TO APPLICATION ROLE app_public;
