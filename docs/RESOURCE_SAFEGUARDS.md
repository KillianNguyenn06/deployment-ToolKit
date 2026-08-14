# Resource Safeguards Guide

## 1. Purpose

This guide explains how the Deployment Toolkit limits Docker resource usage and removes old deployment data on the internal Dev/QC server.

The safeguards protect against four common problems:

1. an application consuming all available memory or CPU;
2. continuous application output filling the disk with Docker logs;
3. Jenkins builds leaving unlimited Docker images and build cache;
4. Jenkins releases accumulating under `/opt/deployment-toolkit`.

These controls reduce risk from toolkit-managed services. They do not set limits for unrelated containers or replace host-level monitoring.

## 2. When the safeguards take effect

`ACTION=build` builds an image but does not start an application container. Build and test containers have temporary CPU, memory and process limits.

`ACTION=deploy` builds the image and uses Docker Compose to create or recreate the selected application containers. Runtime limits, restart policy and log rotation apply to each new container.

With `SERVICE=all`, checkout, validation and Docker build work may overlap. Each validation container is bounded, but their temporary resource use is cumulative. The deployed Go, React and Ruby defaults allow up to approximately 768 MB RAM and 1.5 CPU cores in total (`3 × 256m`, `3 × 0.50 CPU`). Account for Docker build overhead and the host operating system separately.

Existing containers created by an older toolkit version do not receive the new limits automatically. Run a successful deployment with the updated toolkit to recreate them.

## 3. Recommended Jenkins values

### Shared safeguards

| Parameter | Recommended value | Meaning |
|---|---:|---|
| `DOCKER_LOG_MAX_SIZE` | `10m` | Rotate a Docker log file after approximately 10 MB |
| `DOCKER_LOG_MAX_FILES` | `3` | Retain no more than three rotated log files per container |
| `RELEASE_RETENTION` | `5` | Retain the five newest numbered release directories |
| `IMAGE_RETENTION_HOURS` | `72` | Remove unused toolkit images older than 72 hours |
| `PRUNE_BUILD_CACHE` | `true` | Enable cleanup of old unused Docker build cache |
| `BUILD_CACHE_RETENTION_HOURS` | `168` | Keep unused build cache for seven days |

On a Docker server shared with unrelated teams, use:

```text
PRUNE_BUILD_CACHE=false
```

Toolkit image cleanup is restricted by project labels. Docker build-cache cleanup is host-wide, although it removes only unused cache older than the configured age.

### Go backend service

Use these initial values for a long-running Go API or backend service:

| Parameter | Recommended value | Meaning |
|---|---:|---|
| `GO_MEMORY_LIMIT` | `256m` | The running container may use at most approximately 256 MB RAM |
| `GO_CPU_LIMIT` | `0.50` | The running container may use at most half of one CPU core |
| `GO_RESTART_POLICY` | `unless-stopped` | Keep the backend available after Docker or the host restarts |

The backend remains active after Jenkins finishes, but it stays inside the configured CPU and memory limits. If a service is intentionally taken out of operation, stop it through the approved deployment procedure rather than treating a stopped application as a successful deployment.

Use `on-failure` only when the team specifically wants restart attempts for application failures but not normal exits. Use `no` only for exceptional one-time jobs; it is not the recommended IR setting for deployed services.

### React web application

Use these initial values:

| Parameter | Recommended value | Meaning |
|---|---:|---|
| `NODE_BUILD_MEMORY_MB` | `768` | Maximum Node.js heap used during lint and build |
| `REACT_MEMORY_LIMIT` | `256m` | Maximum memory for the running Nginx container |
| `REACT_CPU_LIMIT` | `0.50` | Maximum CPU for the running Nginx container |
| `REACT_RESTART_POLICY` | `unless-stopped` | Keep the deployed web application available |

The Jenkins React validation container is also limited to 1 GB RAM, one CPU core and 256 processes.

### Ruby backend service

Use these initial values for a long-running Rack/Puma service:

| Parameter | Recommended value | Meaning |
|---|---:|---|
| `RUBY_MEMORY_LIMIT` | `256m` | Maximum memory for the running Ruby/Puma container |
| `RUBY_CPU_LIMIT` | `0.50` | Maximum CPU for the running Ruby/Puma container |
| `RUBY_RESTART_POLICY` | `unless-stopped` | Keep the Ruby backend available after Docker or the host restarts |

The Jenkins Ruby validation container is limited to 1 GB RAM, one CPU core and 256 processes. The deployed service must pass its `/health` check within 60 seconds. The Go validation container has the same temporary limits.

## 4. What happens when a limit is reached

### Memory

When an application attempts to exceed its container memory limit, Linux may terminate it as out-of-memory.

- With `on-failure`, Docker restarts the container after an unsuccessful exit.
- With `unless-stopped`, Docker keeps the service available unless an operator explicitly stops it.

Check the result with:

```bash
docker inspect --format='status={{.State.Status}} oom={{.State.OOMKilled}} restarts={{.RestartCount}}' <CONTAINER_NAME>
```

### CPU

The container is throttled when it attempts to use more CPU than configured. It normally remains running but completes work more slowly.

### Logs

Docker rotates the JSON log when it reaches `DOCKER_LOG_MAX_SIZE`. Once `DOCKER_LOG_MAX_FILES` files exist, the oldest rotated file is removed.

With the defaults, application logs use approximately:

```text
10 MB × 3 files = 30 MB per container
```

Small filesystem and metadata overhead may make the actual value slightly different.

## 5. Automatic cleanup after a successful job

Cleanup runs only after all selected services build or deploy successfully.

### Release directories

Jenkins creates releases under:

```text
/opt/deployment-toolkit/projects/<PROJECT_ID>/releases/<BUILD_NUMBER>/
```

The cleanup logic only accepts numeric release directory names and retains the newest `RELEASE_RETENTION` directories. It skips cleanup if the current path does not match the expected `releases/<number>` structure.

### Docker images

Every toolkit-built image receives labels identifying it as toolkit-managed and associating it with a Compose project. Cleanup removes only unused labeled images for that project that are older than `IMAGE_RETENTION_HOURS`.

An image used by a running or stopped container is not considered unused and is not removed by image pruning.

### Build cache

When `PRUNE_BUILD_CACHE=true`, Docker removes unused build cache older than `BUILD_CACHE_RETENTION_HOURS`.

### Jenkins history

The Jenkins job retains:

```text
20 build records
10 archived artifact sets
```

This controls Jenkins storage independently from Docker storage.

## 6. Verify the safeguards on the Ubuntu server

After running Jenkins with `ACTION=deploy`, find the container:

```bash
docker ps -a
```

Check the runtime limits and restart policy:

```bash
docker inspect --format='memory={{.HostConfig.Memory}} cpuNano={{.HostConfig.NanoCpus}} restart={{.HostConfig.RestartPolicy.Name}}' <CONTAINER_NAME>
```

For the default 256 MB and 0.50 CPU configuration, expect values similar to:

```text
memory=268435456 cpuNano=500000000 restart=unless-stopped
```

Check log rotation:

```bash
docker inspect --format='driver={{.HostConfig.LogConfig.Type}} options={{json .HostConfig.LogConfig.Config}}' <CONTAINER_NAME>
```

Expected options:

```text
max-size=10m
max-file=3
```

Observe current resource use without leaving a live dashboard running:

```bash
docker stats --no-stream <CONTAINER_NAME>
```

Inspect Docker disk usage:

```bash
docker system df
```

Count retained releases for one project:

```bash
find /opt/deployment-toolkit/projects/<PROJECT_ID>/releases -mindepth 1 -maxdepth 1 -type d
```

## 7. Choosing values safely

Start with the documented defaults. Increase a limit only when Jenkins logs or Docker inspection show that a valid application workload needs more resources.

Examples:

```text
Small Go or Nginx service: 256m, 0.50 CPU
Larger Go API:             512m, 1.00 CPU
Larger React build heap:   NODE_BUILD_MEMORY_MB=1024
Small Ruby/Puma service:   256m, 0.50 CPU
```

Do not set a service limit close to all memory available on the Docker host. For an `all` run, add the three runtime limits together and leave capacity for parallel validation, Docker builds, Jenkins and the operating system. `disableConcurrentBuilds()` prevents multiple complete runs of this Jenkins job from overlapping.

## 8. Troubleshooting

| Symptom | Check | Action |
|---|---|---|
| Container exited unexpectedly | `OOMKilled` from `docker inspect` | Fix a memory leak or cautiously increase the service memory limit |
| Application is too slow | `docker stats --no-stream` | Verify CPU throttling, then increase the CPU limit only if justified |
| Service does not return after a host restart | Restart policy from `docker inspect` | Use `unless-stopped` for the long-running Go, React and Ruby services |
| Docker storage continues growing | `docker system df` and release directory count | Confirm the last Jenkins job succeeded and cleanup ran in its console log |
| Build cache must remain on shared host | Jenkins parameter | Set `PRUNE_BUILD_CACHE=false` |
| Old container has no limits | Container creation time and inspection | Redeploy it using the updated feature branch |

Do not run broad cleanup commands such as `docker system prune --all` without reviewing which images, containers and caches they will remove.

## 9. IR evidence

Save the following evidence after deployment:

```bash
docker ps
docker stats --no-stream <CONTAINER_NAME>
docker inspect --format='memory={{.HostConfig.Memory}} cpuNano={{.HostConfig.NanoCpus}} restart={{.HostConfig.RestartPolicy.Name}}' <CONTAINER_NAME>
docker inspect --format='options={{json .HostConfig.LogConfig.Config}}' <CONTAINER_NAME>
docker image ls
docker system df
```

The evidence demonstrates that continuous deployment remains functional while the Dev/QC server has explicit resource and storage controls.
