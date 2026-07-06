#!/bin/bash
# Helper to generate Argon2 password hashes for Authelia users
docker run --rm docker.io/authelia/authelia:latest authelia crypto hash generate argon2 --password "$1"
