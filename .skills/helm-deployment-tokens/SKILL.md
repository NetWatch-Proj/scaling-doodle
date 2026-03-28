# Helm Deployment with Token Generation

Generate authentication tokens before Kubernetes deployment and pass them to applications via Helm values.

## Overview

Generate secure tokens in Elixir before deploying to Kubernetes, ensuring the application receives a pre-configured token rather than generating its own.

## When to Use

- Application requires an authentication token
- Token must be known before deployment completes
- Token needs to be displayed in UI after provisioning
- Token should be stored encrypted in database

## Implementation

### Step 1: Token Generation

```elixir
# lib/my_app/helm.ex
defmodule MyApp.Helm do
  @doc """
  Generates a secure random token.
  """
  def generate_token do
    :crypto.strong_rand_bytes(24)
    |> Base.encode16(case: :lower)
  end
end
```

### Step 2: Store Before Deployment

```elixir
# lib/my_app/workers/provision_worker.ex
defmodule MyApp.Workers.ProvisionWorker do
  use Oban.Worker

  alias MyApp.Helm

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resource_id" => id}}) do
    resource = MyApp.get_resource!(id)
    
    # Generate token before deployment
    token = Helm.generate_token()
    
    # Store in database
    MyApp.update_resource(resource, %{token: token})
    
    # Deploy with token
    values = %{
      secrets: %{token: token}
    }
    
    Helm.upgrade_install(resource.name,
      namespace: resource.namespace,
      values: values
    )
  end
end
```

### Step 3: Helm Chart Configuration

**Secret Template:**
```yaml
# templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.instance.name }}-secrets
type: Opaque
stringData:
  TOKEN: {{ .Values.secrets.token | default "" }}
```

**Deployment Template:**
```yaml
# templates/deployment.yaml
spec:
  template:
    spec:
      initContainers:
        - name: copy-config
          image: busybox:1.36
          env:
            - name: TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.instance.name }}-secrets
                  key: TOKEN
          command:
            - sh
            - -c
            - |
              mkdir -p /app/config
              # Substitute environment variables
              sed -e "s|\\${TOKEN}|${TOKEN}|g" \
                  /config-template/app.json > /app/config/app.json
          volumeMounts:
            - name: config
              mountPath: /config-template
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          envFrom:
            - secretRef:
                name: {{ .Values.instance.name }}-secrets
```

**ConfigMap Template:**
```yaml
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.instance.name }}-config
data:
  app.json: |
    {
      "auth": {
        "token": "${TOKEN}"
      }
    }
```

### Step 4: Application Configuration

The application should read the token from its config file:

```elixir
# Application reads token from config
token = File.read!("/app/config/app.json")
  |> Jason.decode!()
  |> get_in(["auth", "token"])
```

## Key Points

### Token Generation Timing

**Generate BEFORE deployment:**
1. Worker generates token
2. Token stored in DB
3. Token passed to Helm
4. Token substituted in config
5. Application starts with token ready

**Benefits:**
- Token is known and can be displayed in UI
- No need to extract from running pod
- Token is available immediately after provisioning
- Can store encrypted in database

### Config Substitution

**Use sed instead of awk:**
```bash
# More reliable for special characters
sed -e "s|\\${TOKEN}|${TOKEN}|g" input.json > output.json
```

### Storage

**Encrypted in database:**
```elixir
attribute :token, MyApp.Vault.Types.EncryptedBinary do
  sensitive? true
end
```

**Access in UI:**
```heex
<code>{@resource.token}</code>
```

## Testing

### Verify Token Flow

```bash
# Check token in secret
kubectl get secret my-app-secrets -n my-namespace \
  -o jsonpath='{.data.TOKEN}' | base64 -d

# Verify token in pod config
kubectl exec -n my-namespace deployment/my-app \
  -- cat /app/config/app.json | jq '.auth.token'
```

## Common Issues

### Init Container Fails

**Problem:** "Config file is empty"

**Solution:** Check sed syntax and environment variable:
```bash
# Debug: Check if env var is set
echo "TOKEN=$TOKEN"

# Use double backslash in sed
sed -e "s|\\${TOKEN}|${TOKEN}|g" ...
```

### Token Not Substituted

**Problem:** Config file contains literal `${TOKEN}`

**Solution:** Ensure ConfigMap template uses `${TOKEN}` syntax:
```yaml
data:
  app.json: |
    {"token": "${TOKEN}"}  # Escaped braces work with sed
```

### Token Mismatch

**Problem:** UI shows different token than pod uses

**Solution:** Ensure token is saved to DB before Helm deployment:
```elixir
# Correct order
{:ok, _} = update_resource(resource, %{token: token})
Helm.upgrade_install(..., values: %{secrets: %{token: token}})
```

## Best Practices

1. **Generate before deploy** - Never extract from running pods
2. **Store encrypted** - Use Cloak for database storage
3. **Display in UI** - Show token in instance details page
4. **Use sed** - More reliable than awk for substitution
5. **Verify init** - Always check config file was written
6. **Length matters** - 48 hex chars = 24 bytes of entropy

## Security Considerations

- Tokens are stored encrypted in DB (AES-256)
- Tokens are passed to Kubernetes as Secrets
- Tokens are injected as environment variables
- Tokens are never logged (sensitive? true)

## Related Skills

- [Ash Encrypted Fields](../ash-encrypted-fields/SKILL.md)
- [LiveView Table Actions](../liveview-table-actions/SKILL.md)
