-- =============================================================================
-- Qlik Cloud Native App - Reference Callbacks
-- =============================================================================

CREATE OR REPLACE PROCEDURE internal._bind_procedures()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    ALTER PROCEDURE internal._mcp_call(STRING, STRING)
        SET EXTERNAL_ACCESS_INTEGRATIONS = (reference('qlik_external_access'))
            SECRETS = ('client_id' = reference('QLIK_CLIENT_ID'), 'client_secret' = reference('QLIK_CLIENT_SECRET'));

    RETURN 'All procedures bound successfully';
END;

CREATE OR REPLACE PROCEDURE setup.register_reference(ref_name STRING, operation STRING, ref_or_alias STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    CASE (operation)
        WHEN 'ADD' THEN
            SELECT SYSTEM$SET_REFERENCE(:ref_name, :ref_or_alias);
        WHEN 'REMOVE' THEN
            SELECT SYSTEM$REMOVE_REFERENCE(:ref_name, :ref_or_alias);
        WHEN 'CLEAR' THEN
            SELECT SYSTEM$REMOVE_ALL_REFERENCES(:ref_name);
    END CASE;

    IF (UPPER(ref_name) = 'QLIK_EXTERNAL_ACCESS' AND operation = 'ADD') THEN
        CALL internal._bind_procedures();
    END IF;

    RETURN 'Reference ' || ref_name || ' ' || operation || ' completed';
END;

GRANT USAGE ON PROCEDURE setup.register_reference(STRING, STRING, STRING) TO APPLICATION ROLE app_public;

CREATE OR REPLACE PROCEDURE setup.get_configuration_for_reference(ref_name STRING)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    tenant STRING;
BEGIN
    CASE (UPPER(ref_name))
        WHEN 'QLIK_EXTERNAL_ACCESS' THEN
            SELECT value INTO tenant FROM internal.config WHERE key = 'qlik_tenant';
            IF (tenant IS NULL) THEN
                RETURN '{"type": "ERROR", "payload": {"message": "Qlik tenant not configured. Set it in the app UI first."}}';
            END IF;
            RETURN '{"type": "CONFIGURATION", "payload": {"host_ports": ["' || tenant || ':443"], "allowed_secrets": "LIST", "secret_references": ["QLIK_CLIENT_ID", "QLIK_CLIENT_SECRET"]}}';
        WHEN 'QLIK_CLIENT_ID' THEN
            RETURN '{"type": "CONFIGURATION", "payload": {"type": "GENERIC_STRING"}}';
        WHEN 'QLIK_CLIENT_SECRET' THEN
            RETURN '{"type": "CONFIGURATION", "payload": {"type": "GENERIC_STRING"}}';
        ELSE
            RETURN '{"type": "ERROR", "payload": {"message": "Unknown reference: ' || ref_name || '"}}';
    END CASE;
END;

GRANT USAGE ON PROCEDURE setup.get_configuration_for_reference(STRING) TO APPLICATION ROLE app_public;

CREATE OR REPLACE PROCEDURE tools.set_qlik_tenant(hostname STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    MERGE INTO internal.config AS t
    USING (SELECT 'qlik_tenant' AS key, :hostname AS value) AS s
    ON t.key = s.key
    WHEN MATCHED THEN UPDATE SET value = s.value
    WHEN NOT MATCHED THEN INSERT (key, value) VALUES (s.key, s.value);
    RETURN 'Tenant set to: ' || hostname;
END;

GRANT USAGE ON PROCEDURE tools.set_qlik_tenant(STRING) TO APPLICATION ROLE app_public;
