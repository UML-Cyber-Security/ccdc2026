# Docker Swarm Prep

- `migrate-docker-swarm.yaml`: Prepares Ubuntu nodes for Swarm usage by installing Docker dependencies, configuring an insecure registry, creating bind-mount paths, and assigning the blue team user to the `docker` group.

Before use, update host targets, usernames, and registry settings to match the current competition environment.
