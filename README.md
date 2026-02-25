# Cloud Init Script

Quick setup for your cloud instance  — user, SSH, firewall, and Node.js/nvm environment 

## Usage

```bash
bash <(wget -qO- "https://raw.githubusercontent.com/zk39/cloud-init/refs/heads/main/deploy.sh") <username> <password> <port>
```

## Example

```bash
bash <(wget -qO- "https://raw.githubusercontent.com/zk39/cloud-init/refs/heads/main/deploy.sh") user mypass123 22
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| username | ✅ | — | New user to create |
| password | ✅ | — | Password for the user |
| port | ❌ | 9122 | Custom SSH port number |
