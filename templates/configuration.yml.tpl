---
theme: light

server:
  address: 'tcp://0.0.0.0:9091'
  buffers:
    read: 4096
    write: 4096
  timeouts:
    read: 6s
    write: 6s
    idle: 30s

log:
  level: info
  format: text

ntp:
  disable_startup_check: true

totp:
  issuer: ${FINDOKU_TOTP_ISSUER}
  period: 30
  skew: 1

identity_validation:
  reset_password:
    jwt_secret: ${FINDOKU_JWT_SECRET}

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 3
      key_length: 32
      salt_length: 16
      memory: 65536
      parallelism: 4

access_control:
  default_policy: deny
  rules:
    - domain:
        - 'magnus.${FINDOKU_DOMAIN}'
      policy: ${FINDOKU_AUTH_POLICY}
      resources:
        - '^/.*$'
    - domain:
        - 'kihub.${FINDOKU_DOMAIN}'
      policy: ${FINDOKU_AUTH_POLICY}
      resources:
        - '^/.*$'
    - domain:
        - 'neuromark.${FINDOKU_DOMAIN}'
      policy: ${FINDOKU_AUTH_POLICY}
      resources:
        - '^/.*$'
    - domain:
        - 'genesis.${FINDOKU_DOMAIN}'
      policy: ${FINDOKU_AUTH_POLICY}
      resources:
        - '^/.*$'

session:
  secret: ${FINDOKU_SESSION_SECRET}
  expiration: 1h
  inactivity: 5m
  cookies:
    - domain: '${FINDOKU_DOMAIN}'
      authelia_url: '${FINDOKU_AUTH_URL}'
      default_redirection_url: '${FINDOKU_DEFAULT_REDIRECT}'

  redis:
    host: 127.0.0.1
    port: 6379

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  encryption_key: ${FINDOKU_STORAGE_SECRET}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
