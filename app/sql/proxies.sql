-- =============================================================================
-- Qlik Cloud Native App - Public Proxy Procedures
-- =============================================================================

-- ---------------------------------------------------------------------------
-- List Apps
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_list_apps(
    limit_val INT DEFAULT 20
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_list_apps(:limit_val) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_list_apps(INT) TO APPLICATION ROLE app_public;

-- ---------------------------------------------------------------------------
-- Get App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_get_app(
    app_id STRING
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_get_app(:app_id) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_get_app(STRING) TO APPLICATION ROLE app_public;

-- ---------------------------------------------------------------------------
-- Create App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_create_app(
    app_name STRING,
    description STRING DEFAULT ''
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_create_app(:app_name, :description) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_create_app(STRING, STRING) TO APPLICATION ROLE app_public;

-- ---------------------------------------------------------------------------
-- Update App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_update_app(
    app_id STRING,
    app_name STRING,
    description STRING DEFAULT ''
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_update_app(:app_id, :app_name, :description) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_update_app(STRING, STRING, STRING) TO APPLICATION ROLE app_public;

-- ---------------------------------------------------------------------------
-- Delete App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_delete_app(
    app_id STRING
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_delete_app(:app_id) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_delete_app(STRING) TO APPLICATION ROLE app_public;

-- ---------------------------------------------------------------------------
-- Copy App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE tools.qlik_copy_app(
    app_id STRING,
    new_name STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_copy_app(:app_id, :new_name) INTO result;
    RETURN result;
END;

GRANT USAGE ON PROCEDURE tools.qlik_copy_app(STRING, STRING) TO APPLICATION ROLE app_public;
