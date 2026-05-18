-- =============================================================================
-- Qlik Cloud Native App - Internal API Procedures
-- =============================================================================

CREATE OR REPLACE PROCEDURE internal._qlik_api_call(
    method STRING,
    path STRING,
    query_params STRING DEFAULT NULL,
    body STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('requests', 'snowflake-snowpark-python')
HANDLER = 'main'
AS $$
import _snowflake
import requests
import json

def get_tenant(session):
    row = session.sql("SELECT value FROM internal.config WHERE key = 'qlik_tenant'").collect()
    if not row or not row[0][0]:
        raise Exception("Qlik tenant not configured. Set it in the app UI first.")
    return row[0][0].strip()

def get_access_token(session):
    tenant = get_tenant(session)
    client_id = _snowflake.get_generic_secret_string('client_id').strip()
    client_secret = _snowflake.get_generic_secret_string('client_secret').strip()
    token_url = f"https://{tenant}/oauth/token"
    resp = requests.post(token_url, data={
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "client_credentials"
    }, headers={"Content-Type": "application/x-www-form-urlencoded"}, timeout=30)
    resp.raise_for_status()
    return resp.json()["access_token"], tenant

def main(session, method: str, path: str, query_params: str = None, body: str = None) -> str:
    try:
        token, tenant = get_access_token(session)
    except requests.exceptions.HTTPError as e:
        return json.dumps({"error": f"Token request failed: {e}", "response": e.response.text[:1000] if e.response else ""})
    except Exception as e:
        return json.dumps({"error": f"Token request exception: {str(e)}"})

    try:
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        url = f"https://{tenant}{path}"
        params = json.loads(query_params) if query_params else None
        data = body if body else None

        resp = requests.request(
            method=method.upper(),
            url=url,
            headers=headers,
            params=params,
            data=data,
            timeout=60
        )
        resp.raise_for_status()

        if resp.status_code == 204:
            return json.dumps({"status": "success", "code": 204})

        return json.dumps(resp.json(), indent=2)
    except requests.exceptions.HTTPError as e:
        return json.dumps({"error": str(e), "response": resp.text[:1000]})
    except Exception as e:
        return json.dumps({"error": str(e)})
$$;

-- ---------------------------------------------------------------------------
-- List Apps
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE internal._qlik_list_apps(
    limit_val INT DEFAULT 20
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_api_call(
        'GET',
        '/api/v1/items',
        '{"resourceType": "app", "limit": ' || :limit_val::STRING || '}',
        NULL
    ) INTO result;
    RETURN result;
END;

-- ---------------------------------------------------------------------------
-- Get App Details
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE internal._qlik_get_app(
    app_id STRING
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_api_call(
        'GET',
        '/api/v1/apps/' || :app_id,
        NULL,
        NULL
    ) INTO result;
    RETURN result;
END;

-- ---------------------------------------------------------------------------
-- Create App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE internal._qlik_create_app(
    app_name STRING,
    description STRING DEFAULT ''
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
    body STRING;
BEGIN
    body := '{"attributes": {"name": "' || :app_name || '", "description": "' || :description || '"}}';
    CALL internal._qlik_api_call(
        'POST',
        '/api/v1/apps',
        NULL,
        :body
    ) INTO result;
    RETURN result;
END;

-- ---------------------------------------------------------------------------
-- Update App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE internal._qlik_update_app(
    app_id STRING,
    app_name STRING,
    description STRING DEFAULT ''
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
    body STRING;
BEGIN
    body := '{"attributes": {"name": "' || :app_name || '", "description": "' || :description || '"}}';
    CALL internal._qlik_api_call(
        'PUT',
        '/api/v1/apps/' || :app_id,
        NULL,
        :body
    ) INTO result;
    RETURN result;
END;

-- ---------------------------------------------------------------------------
-- Delete App
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE internal._qlik_delete_app(
    app_id STRING
)
RETURNS STRING
LANGUAGE SQL
AS
DECLARE
    result STRING;
BEGIN
    CALL internal._qlik_api_call(
        'DELETE',
        '/api/v1/apps/' || :app_id,
        NULL,
        NULL
    ) INTO result;
    RETURN result;
END;
