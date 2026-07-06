---
theme: light

server:
  address: 'tcp://0.0.0.0:9091'
  buffers:
    read: ${FINDOKU_SERVER_BUFFERS_READ}
    write: ${FINDOKU_SERVER_BUFFERS_WRITE}
  timeouts:
    read: ${FINDOKU_SERVER_TIMEOUTS_READ}
    write: ${FINDOKU_SERVER_TIMEOUTS_WRITE}
    idle: ${FINDOKU_SERVER_TIMEOUTS_IDLE}

log:
  level: ${FINDOKU_LOG_LEVEL}
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
      # iterations, key_length, salt_length, memory, parallelism are hardcoded
      # constants — see config/authelia.example.yaml for documentation.
      # Changing these breaks all existing argon2id password hashes.
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
  expiration: ${FINDOKU_SESSION_EXPIRATION}
  inactivity: ${FINDOKU_SESSION_INACTIVITY}
  cookies:
    - domain: '${FINDOKU_DOMAIN}'
      authelia_url: '${FINDOKU_AUTH_URL}'
      default_redirection_url: '${FINDOKU_DEFAULT_REDIRECT}'

  redis:
    host: 127.0.0.1
    port: 6379

regulation:
  max_retries: ${FINDOKU_REGULATION_MAX_RETRIES}
  find_time: ${FINDOKU_REGULATION_FIND_TIME}
  ban_time: ${FINDOKU_REGULATION_BAN_TIME}

storage:
  encryption_key: ${FINDOKU_STORAGE_SECRET}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
