# myDKG ID — Thin Authelia wrapper (no secrets baked in)
#
# All sensitive config (configuration.yml, users_database.yml, .secrets, db.sqlite3)
# is mounted as a volume at runtime. Nothing in this image is secret.
#
# Build:  docker build -t ghcr.io/batchputz/mydkg-authelia:latest .
# Push:   docker push ghcr.io/batchputz/mydkg-authelia:latest
#
# On the target machine, sync the authelia/ directory and run:
#   docker run -d --name mydkg-authelia --network host \
#     -v /path/to/authelia:/config \
#     ghcr.io/batchputz/mydkg-authelia:latest

FROM docker.io/authelia/authelia:latest

EXPOSE 9091

# No CMD override — inherits from base image (starts Authelia)
# No config copied — all of /config is mounted at runtime
