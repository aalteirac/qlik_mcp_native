# Qlik Cloud Tools for Snowflake Cortex Agents

A Snowflake Native App that exposes **Qlik Cloud Apps REST API** as tools for a **Cortex Agent**.

## Setup

### 1. Install the app

Install from the application package. During setup you will be prompted to provide:
- **QLIK_CLIENT_ID** — a `GENERIC_STRING` secret with your Qlik OAuth2 client ID
- **QLIK_CLIENT_SECRET** — a `GENERIC_STRING` secret with your Qlik OAuth2 client secret

### 2. Configure in the app UI

Open the app's Streamlit interface and follow the two steps:

1. **Enter your Qlik tenant hostname** (e.g. `mytenant.us.qlikcloud.com`) and click **Connect**. This saves the tenant and prompts you to approve the external access integration.
2. Once the EAI is approved, click **Create Agent** to deploy the Cortex Agent with all Qlik tools.

### 3. Grant warehouse access

> **IMPORTANT: An account admin must run the following before the agent can execute tools:**
>
> ```sql
> GRANT CALLER USAGE ON WAREHOUSE <my_warehouse> TO APPLICATION QLIK_APP;
> ```

## Usage

Once configured, the agent appears in **Snowflake Intelligence** and can be tested from the app's **Test Agent** tab.
