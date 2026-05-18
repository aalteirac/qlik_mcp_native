-- =============================================================================
-- Qlik Cloud Native App - MCP Call Procedure
-- =============================================================================

CREATE OR REPLACE PROCEDURE internal._mcp_call(
    tool_name STRING,
    arguments STRING
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

def get_access_token(session, tenant):
    client_id = _snowflake.get_generic_secret_string('client_id').strip()
    client_secret = _snowflake.get_generic_secret_string('client_secret').strip()
    token_url = f"https://{tenant}/oauth/token"
    resp = requests.post(token_url, json={
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret
    }, headers={"Content-Type": "application/json"}, timeout=30)
    resp.raise_for_status()
    return resp.json()["access_token"]

def mcp_post(mcp_url, headers, payload):
    resp = requests.post(mcp_url, headers=headers, json=payload, stream=True, timeout=180)
    resp.raise_for_status()
    session_id = resp.headers.get("Mcp-Session-Id")

    result = None
    for line in resp.iter_lines(decode_unicode=True):
        if line and line.startswith("data:"):
            data = line[5:].strip()
            if data:
                try:
                    result = json.loads(data)
                except json.JSONDecodeError:
                    pass

    if result is None:
        try:
            result = json.loads(resp.text)
        except:
            result = {"raw": resp.text[:2000]}

    return result, session_id

def main(session, tool_name: str, arguments=None) -> str:
    step = "init"
    try:
        step = "get_tenant"
        tenant = get_tenant(session)
        step = "get_token"
        token = get_access_token(session, tenant)
    except requests.exceptions.HTTPError as e:
        return json.dumps({"error": f"[{step}] Token request failed: {e}", "response": e.response.text[:1000] if e.response else ""})
    except Exception as e:
        return json.dumps({"error": f"[{step}] {str(e)}"})

    mcp_url = f"https://{tenant}/api/ai/mcp"
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "Authorization": f"Bearer {token}"
    }

    try:
        step = "mcp_initialize"
        init_payload = {
            "jsonrpc": "2.0",
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "snowflake-native-app", "version": "1.0"}
            },
            "id": 1
        }
        init_result, session_id = mcp_post(mcp_url, headers, init_payload)

        if isinstance(init_result, dict) and "error" in init_result:
            return json.dumps({"error": f"[{step}] MCP initialize failed", "detail": init_result.get("error")})

        if session_id:
            headers["Mcp-Session-Id"] = session_id

        step = "parse_arguments"
        if arguments is None or arguments == "" or arguments == "null":
            args = {}
        elif isinstance(arguments, dict):
            args = arguments
        elif isinstance(arguments, str):
            try:
                args = json.loads(arguments)
            except (json.JSONDecodeError, TypeError):
                args = {}
        else:
            args = {}

        step = f"tools/call:{tool_name}"
        call_payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {"name": tool_name, "arguments": args},
            "id": 2
        }
        result, _ = mcp_post(mcp_url, headers, call_payload)

        if isinstance(result, dict):
            if "result" in result:
                return json.dumps(result["result"], indent=2)
            elif "error" in result:
                return json.dumps({"error": f"[{step}] {result['error']}"}, indent=2)

        return json.dumps(result, indent=2)
    except requests.exceptions.HTTPError as e:
        return json.dumps({"error": f"[{step}] HTTP {e}", "response": e.response.text[:500] if e.response else ""})
    except Exception as e:
        return json.dumps({"error": f"[{step}] {str(e)}"})
$$;
