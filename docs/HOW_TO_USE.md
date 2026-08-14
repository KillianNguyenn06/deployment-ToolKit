# How to Use the Deployment Toolkit

## 1. Purpose and supported scope

This toolkit lets one internal Jenkins Pipeline build or deploy application source from separate Go, React and Ruby repositories to an internal Dev/QC Docker server over SSH.

The supported flow is:

```text
Jenkins Pipeline from SCM
  -> validate parameters
  -> checkout selected application repositories in parallel
  -> run selected application tests in parallel
  -> create an isolated release
  -> synchronize toolkit and source over SSH
  -> run Docker Compose on the local server
  -> verify selected images and containers
```

The toolkit supports these selections:

| `SERVICE` | Result |
|---|---|
| `go-backend` | Process only the Go repository and service |
| `react-frontend` | Process only the React repository and service |
| `ruby-service` | Process only the Ruby repository and service |
| `all` | Process Go, React and Ruby together in one Jenkins run |

This toolkit is for an internal/on-premises Dev or QC Docker host. It is not an AWS/ECS, cloud-production, or public-host deployment pipeline.

## 2. What is stored in each repository

The deployment logic remains separate from application business logic.

```text
deployment-ToolKit repository
├── Jenkinsfile                  Jenkins orchestration and parameters
├── compose.yaml                 Reusable Go, React and Ruby service slots
├── docker/
│   ├── go.Dockerfile            Multi-stage Go/distroless image
│   ├── react.Dockerfile         Multi-stage React/Nginx image
│   └── ruby.Dockerfile          Multi-stage Ruby/Puma image
├── scripts/deploy.sh            Build/deploy/verify logic on local server
├── .env.example                 Manual Compose configuration example
└── docs/                        Usage and safeguard documentation

separate application repositories
├── Go application repository
├── React application repository
└── Ruby application repository
```

Application repository URLs, branches, versions, ports, image names and resource limits are supplied through Jenkins parameters. A new project does not require hard-coding its repository name in the toolkit.

## 3. Application repository contracts

### 3.1 Go

The Go repository must:

- contain `go.mod` at its root;
- optionally contain `go.sum`;
- compile with `CGO_ENABLED=0`;
- have a buildable package supplied through `GO_BUILD_PACKAGE`;
- remain running when deployed as a service;
- use the `PORT` environment variable if it provides an HTTP server.

The final image contains the compiled binary in a non-root distroless runtime. The large Go compiler image remains only in the builder stage.

### 3.2 React

The React repository must:

- contain `package.json` and `package-lock.json` at its root;
- support `npm ci`;
- support `npm run lint`;
- support `npm run build`;
- generate production files in `dist/`.

Node.js is used only during build. The final runtime serves `dist/` through Nginx on container port `80`.

### 3.3 Ruby

The Ruby repository must:

- contain a `Gemfile` at its root;
- preferably commit `Gemfile.lock` for reproducible dependencies;
- provide a Rack-compatible `config.ru`;
- include Puma in its production bundle;
- provide the test file configured by `RUBY_TEST_FILE`;
- listen on `PORT`, default `9292`;
- provide `GET /health` returning a successful HTTP response.

If an application repository has no `Gemfile.lock`, the builder generates one and copies that exact dependency resolution into the non-root runtime image. Real projects should still commit the lockfile.

## 4. Required infrastructure

### 4.1 Jenkins controller or agent

The Jenkins node running this Pipeline must have:

- Git;
- Docker Engine access;
- Docker Compose v2;
- SSH client;
- `rsync`;
- a Jenkins node label named `docker`;
- enough capacity for the selected validation containers and Docker builds.

Recommended Jenkins plugins:

- Pipeline;
- Git;
- SSH Agent;
- Credentials Binding.

This Pipeline uses `disableConcurrentBuilds()`, so two executions of this same Jenkins job cannot overlap. One executor is a conservative starting point for a small Dev/QC machine.

### 4.2 Local Docker server

The SSH deployment target must have:

- Linux and Bash;
- Docker Engine;
- Docker Compose v2;
- `rsync`;
- an SSH user permitted to run Docker;
- a writable toolkit base directory.

An administrator can prepare the exact deployment directory:

```bash
sudo mkdir -p /opt/deployment-toolkit
sudo chown DEPLOYMENT_USER:DEPLOYMENT_USER /opt/deployment-toolkit
```

Verify the target server:

```bash
docker version
docker compose version
rsync --version
systemctl is-active docker
```

Docker access grants strong control over the host. Use a dedicated internal Dev/QC server and a dedicated deployment key.

## 5. Configure SSH authentication

### 5.1 Create a deployment key

Run as the real local-server deployment user. Replace `DEPLOYMENT_USER` with that username.

```bash
mkdir -p /home/DEPLOYMENT_USER/.ssh
chmod 700 /home/DEPLOYMENT_USER/.ssh
ssh-keygen -t ed25519 -f /home/DEPLOYMENT_USER/.ssh/jenkins-local-server -N "" -C "jenkins-local-server-deploy"
cat /home/DEPLOYMENT_USER/.ssh/jenkins-local-server.pub >> /home/DEPLOYMENT_USER/.ssh/authorized_keys
chmod 600 /home/DEPLOYMENT_USER/.ssh/authorized_keys
```

Do not commit either key to Git.

### 5.2 Add the private key to Jenkins

Open:

```text
Manage Jenkins
-> Credentials
-> System
-> Global credentials
-> Add Credentials
```

Use:

```text
Kind: SSH Username with private key
Scope: Global
ID: local-server-ssh
Username: the real local-server deployment user
Private key: Enter directly, then paste the contents of the jenkins-local-server private-key file
```

### 5.3 Add the verified server host key

Create a `known_hosts` file from a trusted network and verify its fingerprint with the server administrator:

```bash
ssh-keyscan -t ed25519 LOCAL_SERVER_HOST > local-server-known_hosts
```

Upload that file to Jenkins:

```text
Kind: Secret file
Scope: Global
ID: local-server-known-hosts
File: local-server-known_hosts
```

The Pipeline uses strict host-key checking. Do not replace it with an option that automatically trusts unknown hosts.

## 6. Configure GitHub access

For public repositories, use HTTPS URLs and leave `GIT_CREDENTIALS_ID` blank:

```text
https://github.com/ORGANIZATION/REPOSITORY.git
```

HTTPS is also useful on internal networks that block GitHub SSH port `22`.

For private application repositories, add an appropriate Jenkins Git credential and set its ID in `GIT_CREDENTIALS_ID`. The configured credential must be able to read every selected private application repository.

Never store GitHub private keys, tokens or passwords in this repository or in Jenkins build parameters.

## 7. Create the Jenkins job

Create one Jenkins **Pipeline** job. A recommended name is:

```text
Deploy.MultiService.Local
```

Under **Pipeline**, configure:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/ORGANIZATION/deployment-ToolKit.git
Credentials: None for a public HTTPS toolkit repository
Branch Specifier: */develop
Script Path: Jenkinsfile
```

Use `develop` for the integrated Dev/QC version. During development, point the job to the specific feature branch being tested. Run the job once after changing the SCM branch, then refresh the page so Jenkins loads any changed parameters.

## 8. Jenkins parameter reference

### 8.1 General selection

| Parameter | Purpose | Example |
|---|---|---|
| `SERVICE` | Select one service or all three | `all` |
| `ACTION` | `build` creates images; `deploy` also starts/updates containers | `build` first |
| `ENVIRONMENT` | Target environment supported by this version | `dev` |
| `PROJECT_ID` | Lowercase project slug used for release and Compose isolation | `customer-portal` |
| `RUN_TESTS` | Run selected technology checks before packaging | `true` |
| `GIT_CREDENTIALS_ID` | Optional credential shared by selected private app repositories | blank for public HTTPS |

`PROJECT_ID` must contain 2-63 lowercase letters, numbers or hyphens. Different projects should use different IDs.

### 8.2 Go

| Parameter | Purpose | Example |
|---|---|---|
| `GO_REPO_URL` | Go application repository | `https://github.com/org/go-api.git` |
| `GO_REPO_BRANCH` | Branch to checkout | `develop` |
| `GO_BUILD_PACKAGE` | Package that produces the service binary | `./cmd/server` or `.` |
| `GO_VERSION` | Builder version compatible with `go.mod` | `1.26.5` |
| `GO_IMAGE_REPOSITORY` | Image name without tag | `local/go-api` |
| `GO_HOST_PORT` | Port exposed on the Docker host | `8081` |
| `GO_CONTAINER_PORT` | Port expected inside the container | `8080` |
| `GO_RESTART_POLICY` | Long-running container restart behavior | `unless-stopped` |
| `GO_MEMORY_LIMIT` | Runtime memory limit | `256m` |
| `GO_CPU_LIMIT` | Runtime CPU limit in cores | `0.50` |

### 8.3 React

| Parameter | Purpose | Example |
|---|---|---|
| `REACT_REPO_URL` | React application repository | `https://github.com/org/web-ui.git` |
| `REACT_REPO_BRANCH` | Branch to checkout | `develop` |
| `NODE_VERSION` | Node builder version | `22` |
| `NODE_BUILD_MEMORY_MB` | Maximum Node heap used during validation/build | `768` |
| `REACT_IMAGE_REPOSITORY` | Image name without tag | `local/web-ui` |
| `REACT_HOST_PORT` | Port exposed on the Docker host | `3000` |
| `REACT_CONTAINER_PORT` | Nginx container port; keep this value | `80` |
| `REACT_RESTART_POLICY` | Long-running container restart behavior | `unless-stopped` |
| `REACT_MEMORY_LIMIT` | Runtime memory limit | `256m` |
| `REACT_CPU_LIMIT` | Runtime CPU limit in cores | `0.50` |

### 8.4 Ruby

| Parameter | Purpose | Example |
|---|---|---|
| `RUBY_REPO_URL` | Ruby application repository | `https://github.com/org/ruby-api.git` |
| `RUBY_REPO_BRANCH` | Branch to checkout | `develop` |
| `RUBY_VERSION` | Ruby builder/runtime version | `3.4.5` |
| `RUBY_TEST_FILE` | Test entry relative to repository root | `test/app_test.rb` |
| `RUBY_IMAGE_REPOSITORY` | Image name without tag | `local/ruby-api` |
| `RUBY_HOST_PORT` | Port exposed on the Docker host | `9292` |
| `RUBY_CONTAINER_PORT` | Puma and health-check port; keep this value | `9292` |
| `RUBY_RESTART_POLICY` | Long-running container restart behavior | `unless-stopped` |
| `RUBY_MEMORY_LIMIT` | Runtime memory limit | `256m` |
| `RUBY_CPU_LIMIT` | Runtime CPU limit in cores | `0.50` |

### 8.5 Local server and credentials

| Parameter | Purpose | Example |
|---|---|---|
| `LOCAL_SERVER_HOST` | Internal Docker host address | `172.16.10.20` |
| `LOCAL_SERVER_USER` | Username stored in the SSH credential | `deployment-user` |
| `LOCAL_SERVER_BASE_DIR` | Toolkit release root on target | `/opt/deployment-toolkit` |
| `SSH_CREDENTIALS_ID` | SSH Username with private key credential | `local-server-ssh` |
| `SSH_KNOWN_HOSTS_CREDENTIALS_ID` | Verified host-key secret file | `local-server-known-hosts` |

`LOCAL_SERVER_USER` must match the username associated with the SSH key. A different username commonly causes `Permission denied (publickey,password)`.

### 8.6 Storage and log safeguards

| Parameter | Recommended value | Purpose |
|---|---:|---|
| `DOCKER_LOG_MAX_SIZE` | `10m` | Rotate each Docker JSON log file at this size |
| `DOCKER_LOG_MAX_FILES` | `3` | Keep this many rotated log files per container |
| `RELEASE_RETENTION` | `5` | Keep the newest numbered release directories |
| `IMAGE_RETENTION_HOURS` | `72` | Remove older unused toolkit-managed project images |
| `PRUNE_BUILD_CACHE` | `false` on a shared host | Enable host-wide cleanup of unused old build cache |
| `BUILD_CACHE_RETENTION_HOURS` | `168` | Build-cache age threshold when pruning is enabled |

See [RESOURCE_SAFEGUARDS.md](RESOURCE_SAFEGUARDS.md) before increasing limits or enabling cache pruning on a shared Docker host.

## 9. Run one service

Use **Build with Parameters**.

1. Select one `SERVICE`.
2. Set that service's repository URL, branch and build configuration.
3. Use a unique host port.
4. Set `ACTION=build` and run Jenkins.
5. After build succeeds, keep the parameters unchanged, set `ACTION=deploy`, and run again.

Unused service parameters may retain their defaults. Only the selected repository is checked out, tested, synchronized and processed.

Example Go build:

```text
SERVICE=go-backend
ACTION=build
ENVIRONMENT=dev
PROJECT_ID=customer-portal
GO_REPO_URL=https://github.com/org/go-api.git
GO_REPO_BRANCH=develop
GO_BUILD_PACKAGE=./cmd/server
GO_VERSION=1.26.5
GO_IMAGE_REPOSITORY=local/customer-portal-api
GO_HOST_PORT=8081
GO_CONTAINER_PORT=8080
RUN_TESTS=true
```

## 10. Run all three repositories in one click

Select:

```text
SERVICE=all
ACTION=build
```

Supply valid values for all three repositories. Keep the host ports unique, for example:

```text
GO_HOST_PORT=8081
REACT_HOST_PORT=3000
RUBY_HOST_PORT=9292
```

The first run should always use `ACTION=build`. It proves:

- all three repository branches can be checked out;
- Go, React and Ruby validation passes;
- source synchronization succeeds;
- Compose configuration is valid;
- all three images can be built and inspected.

After it succeeds, keep the parameters unchanged and run:

```text
SERVICE=all
ACTION=deploy
```

The deployment uses one remote Docker Compose operation for the three selected profiles. Jenkins then confirms each selected container is running and waits for configured health checks.

## 11. What Jenkins does during a run

| Stage | Behavior |
|---|---|
| Validate parameters | Rejects unsafe values, missing selected repos, invalid versions and duplicate host ports |
| Checkout toolkit | Loads the deployment files from the configured toolkit SCM branch |
| Checkout applications | Checks selected repositories out into isolated source directories; `all` uses parallel branches |
| Test applications | Runs stack-specific tests in limited temporary containers; `all` uses parallel branches |
| Validate Compose | Activates selected profiles and validates the Compose model |
| Prepare remote configuration | Generates `.env.remote` with target paths, tags and limits |
| Sync release | Creates a numbered remote release and synchronizes toolkit/source files over SSH |
| Build or deploy | Runs `scripts/deploy.sh` on the local Docker server |
| Post actions | Archives Compose, Dockerfile, script and generated-environment evidence |

Each selected image tag includes the Jenkins build number and that application's short Git commit. Each remote release is stored under:

```text
/opt/deployment-toolkit/projects/PROJECT_ID/releases/BUILD_NUMBER/
```

## 12. Verify a deployment

These commands may be run from any directory on the Ubuntu Docker server.

List containers for one Compose project:

```bash
docker ps --filter "label=com.docker.compose.project=PROJECT_ID-dev"
```

Verify React and Ruby HTTP endpoints using the configured host ports:

```bash
curl -I http://localhost:3000/
curl -i http://localhost:9292/health
```

For a Go HTTP server, call its application health endpoint. For an intentionally non-HTTP long-running worker, verify that the container remains running instead.

Inspect current resource use:

```bash
docker stats --no-stream $(docker ps -q --filter "label=com.docker.compose.project=PROJECT_ID-dev")
```

Inspect configured limits and restart policy for a container:

```bash
docker inspect --format='name={{.Name}} status={{.State.Status}} memory={{.HostConfig.Memory}} cpu={{.HostConfig.NanoCpus}} restart={{.HostConfig.RestartPolicy.Name}}' CONTAINER_NAME
```

With `256m`, `0.50` CPU and `unless-stopped`, expect approximately:

```text
memory=268435456 cpu=500000000 restart=unless-stopped
```

Inspect log rotation:

```bash
docker inspect --format='driver={{.HostConfig.LogConfig.Type}} options={{json .HostConfig.LogConfig.Config}}' CONTAINER_NAME
```

Expected defaults:

```text
driver=json-file
max-size=10m
max-file=3
```

## 13. Stop or replace a deployment

Normal updates should be performed by rerunning Jenkins with `ACTION=deploy`. Compose recreates services whose image/configuration changed and keeps the long-running application available under its restart policy.

To intentionally stop one complete project manually, use a retained release containing that project's `.env`:

```bash
cd /opt/deployment-toolkit/projects/PROJECT_ID/releases/BUILD_NUMBER
docker compose --env-file .env --file compose.yaml --profile all down
```

Confirm the exact `PROJECT_ID` and release directory before running `down`. Do not use broad commands such as `docker system prune --all` as a substitute for project-scoped operation.

This version does not provide an automated rollback action. If rollback is required by the team, define and test an approved procedure before production use. This toolkit is currently scoped to internal Dev/QC deployment.

## 14. Resource behavior

Runtime limits are per container. With all defaults, three deployed services can collectively use up to approximately:

```text
Memory: 3 × 256 MB = 768 MB
CPU:    3 × 0.50 = 1.50 cores
Logs:   3 × 10 MB × 3 files = approximately 90 MB
```

Temporary validation containers are each capped at 1 GB memory, 1 CPU and 256 processes. During `SERVICE=all`, their usage may overlap. Docker image builds also need additional memory and disk space. Leave capacity for Jenkins, Docker and the operating system.

Cleanup runs only after every selected service succeeds. It retains configured releases, removes qualifying unused project-labelled images, and optionally prunes old unused build cache.

## 15. Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| New Jenkins parameters do not appear | Job has not loaded the changed Jenkinsfile | Run once, refresh, then open **Build with Parameters** |
| GitHub SSH port 22 times out | Network blocks SSH to GitHub | Use the repository's public HTTPS URL or an approved SSH-over-443 setup |
| `No ED25519 host key is known for github.com` | Jenkins SCM uses SSH without a verified GitHub host key | Prefer public HTTPS or configure the verified GitHub key in Jenkins |
| `Permission denied (publickey,password)` | Wrong local-server username/key pair | Make `LOCAL_SERVER_USER` match the SSH credential username and authorized key |
| `Couldn't find any revision to build` | Requested application branch does not exist | Create/push the branch or select the repository's existing branch |
| Go requires a newer toolchain | `GO_VERSION` is lower than the `go` directive | Set `GO_VERSION` to a compatible published builder version |
| Docker build cannot find `go.sum` | Application has no lock file | Current Go Dockerfile accepts optional `go.sum`; ensure Jenkins uses the latest toolkit branch |
| Ruby cannot write `/app/Gemfile.lock` | Old runtime image did not receive the builder lockfile | Use the current Ruby Dockerfile and rebuild through Jenkins |
| Container is unhealthy | Application did not start or health endpoint failed | Run `docker logs CONTAINER_NAME --tail 100` and inspect `.State.Health` |
| `curl` resets for a Go service | The selected workload is not an HTTP server | Verify container status; use HTTP only when the application exposes an endpoint |
| Duplicate host-port error | Selected services use the same host port | Assign a different host port to each selected service |
| Docker storage grows | Failed jobs skip cleanup or retention is too high | Inspect `docker system df`, successful cleanup logs and retained releases |
| Jenkins ends with `ssh-agent -k` | Normal credential cleanup after an earlier error | Search upward for the first failed command; cleanup is not the root cause |

Useful diagnostics:

```bash
docker ps -a
docker image ls
docker system df
docker logs CONTAINER_NAME --tail 100
docker inspect CONTAINER_NAME
```

## 16. IR evidence and measurement

Do not report target improvements without measured evidence.

### 16.1 One-click multi-repository evidence

Save the successful Jenkins console output showing:

- three parallel checkout branches;
- three parallel test branches;
- three parallel synchronization branches;
- one `SERVICE=all` build;
- one `SERVICE=all` deployment;
- image inspection for Go, React and Ruby;
- all selected containers running;
- Ruby health verification.

### 16.2 Go image-size evidence

On the Docker server, use the exact image repository and tag printed by Jenkins:

```bash
docker image ls GO_IMAGE_REPOSITORY
docker image inspect GO_IMAGE_REPOSITORY:GO_IMAGE_TAG --format='bytes={{.Size}}'
```

Record both the old image and optimized image on the same host. Calculate:

```text
size reduction percent = (old size - new size) / old size × 100
size reduction factor  = old size / new size
```

The Dockerfile implements the multi-stage/distroless technique, but the IR should use the measured image size rather than assuming it is exactly 28.1 MB.

### 16.3 Deployment-time evidence

Measure the same three services and commits using:

1. the previous manual procedure;
2. the successful `SERVICE=all` Jenkins procedure.

Calculate:

```text
time reduction percent = (manual duration - Jenkins duration) / manual duration × 100
```

Only claim 90% when the measured result supports it.

### 16.4 Closeout checklist

- [x] Independent toolkit repository
- [x] Parameterized repository URLs and branches
- [x] Go, React and Ruby stack templates
- [x] SSH deployment to internal local server
- [x] `SERVICE=all` from three independent repositories
- [x] Parallel checkout, testing and synchronization
- [x] Docker Compose profiles and variable substitution
- [x] Multi-stage Go/distroless packaging
- [x] Resource, log and retention safeguards
- [x] Successful all-service build and deployment test
- [x] Successful individual Go, React and Ruby regression builds
- [ ] Record old and optimized Go image sizes
- [ ] Record manual and Jenkins deployment durations
- [ ] Add the Jenkins job link to the IR
- [ ] Publish this guide to the team Wiki
- [ ] Attach console logs and Docker evidence
- [ ] Complete Sprint Review demo and SM/QA/PM verification

## 17. Git workflow for toolkit maintenance

Use `develop` as the integration branch. Do not implement changes directly on `develop` or `main`.

```text
develop
  -> feature/*, fix/* or docs/* branch
  -> commit and push the working branch
  -> Jenkins test the working branch
  -> Pull Request into develop
```

Use `main` only according to the team's approved release process. Documentation changes should use a `docs/*` branch; deployment changes should use a `feature/*` or `fix/*` branch.
