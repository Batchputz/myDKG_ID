# myDKG ID (Authelia) - Standalone Authentication Stack

This stack provides a reusable authentication portal (Authelia) branded as "myDKG ID" for multiple solutions.

## Structure

```
myDKG_ID/
├── podman-compose.yml        # Authelia + Redis + NGINX portal
├── authelia/                 # Config and data (migrated)
│   ├── configuration.yml
│   └── users_database.yml
├── redis/                    # Redis persistence
├── nginx/
│   ├── nginx.conf            # Serves auth.findoku.de on 8443 (dev) and 443 (prod)
│   └── certs/
├── setup-auth.sh             # Optional helper (copied from Magnus)
├── create-user.sh            # Password hash helper
└── README.md                 # This file
```

## Migrate data from Magnus

From the Magnus root:

```bash
# Copy configuration and data
rsync -a ./authelia/ \
  /home/Batchputz/urkundi/clients/DKG_Dresdner_Konzeptberatungsgesellschaft_mbH/solutions/myDKG_ID/authelia/

rsync -a ./redis/ \
  /home/Batchputz/urkundi/clients/DKG_Dresdner_Konzeptberatungsgesellschaft_mbH/solutions/myDKG_ID/redis/

# Copy dev certs (or place production certs accordingly)
rsync -a ./certs/ \
  /home/Batchputz/urkundi/clients/DKG_Dresdner_Konzeptberatungsgesellschaft_mbH/solutions/myDKG_ID/nginx/certs/
```

Verify in `authelia/configuration.yml`:
- cookie domain remains `findoku.de`
- dev: `authelia_url: https://auth.findoku.de:8443`
- prod: `authelia_url: https://auth.findoku.de`

## Run myDKG ID

```bash
cd /home/Batchputz/urkundi/clients/DKG_Dresdner_Konzeptberatungsgesellschaft_mbH/solutions/myDKG_ID
podman-compose up -d
```

Dev portal: https://auth.findoku.de:8443  
Prod portal: https://auth.findoku.de

## Notes
- Each solution keeps its own Redis for Authelia sessions (scoped per stack).
- Magnus and other solutions must point their auth_request verify to the external portal:
  - Dev: `https://auth.findoku.de:8443/api/verify`
  - Prod: `https://auth.findoku.de/api/verify`
