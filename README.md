# Deployment Toolkit — Go, React and Ruby SSH deployment

This repository provides one parameterized Jenkins Pipeline for building or deploying Go, React and Ruby services on an internal Dev/QC Docker server over SSH. Application repositories remain separate from the deployment logic.

```text
Jenkins parameters
  -> select Go, React, Ruby or all
  -> checkout selected application repositories in parallel
  -> run selected technology validations in parallel
  -> rsync an isolated release over SSH
  -> build or deploy selected Compose services together
  -> verify every selected image and container
```

## 1. Application contracts

### Go

The Go repository must:

- contain `go.mod` at its root (`go.sum` is optional);
- compile with `CGO_ENABLED=0`;
- expose one buildable package, configured with `GO_BUILD_PACKAGE`;
- use the `PORT` environment variable if it is a web service.

The final image uses a distroless non-root runtime. The deployed Go backend is treated as a long-running service and should provide a health or HTTP endpoint for runtime verification.

### React

The React repository must:

- contain `package.json` and `package-lock.json` at its root;
- support `npm run lint` for Jenkins validation;
- support `npm run build`;
- produce static production files in `dist/`.

The build stage uses Node.js. The final image contains only Nginx and the generated `dist/` files.
`NODE_BUILD_MEMORY_MB` caps the Node.js heap during linting and production builds.

### Ruby

The Ruby repository must:

- contain a `Gemfile` at its root (`Gemfile.lock` is strongly recommended);
- expose a Rack-compatible `config.ru` application;
- provide the test entry configured by `RUBY_TEST_FILE`;
- listen on the `PORT` environment variable, default `9292`;
- provide `GET /health` for deployment verification.

The Ruby image uses a separate dependency builder and a non-root Puma runtime. Jenkins waits for the Docker health check before declaring `ACTION=deploy` successful.

## 2. Resource and storage safeguards

Every deployed service has explicit CPU, memory and process limits. Docker JSON logs rotate at `10m` with three files by default, preventing an application that prints continuously from filling the server disk. For `SERVICE=all`, limits remain per container, so the maximum combined runtime allocation is the sum of the three selected service limits.

After a successful build or deployment, the toolkit:

- retains only the newest `RELEASE_RETENTION` numbered release directories, default `5`;
- removes unused toolkit-managed images older than `IMAGE_RETENTION_HOURS`, default `72`;
- removes unused Docker build cache older than `BUILD_CACHE_RETENTION_HOURS`, default `168`, when `PRUNE_BUILD_CACHE=true`;
- lets Jenkins retain 20 build records and 10 artifact sets.

Image cleanup is restricted through toolkit and project labels. Build-cache cleanup is Docker-host-wide but only removes unused cache older than the configured threshold; disable it on a shared builder by setting `PRUNE_BUILD_CACHE=false`.

These settings apply when Compose creates or recreates a container. They do not retroactively limit an already-running container created by an earlier version of the toolkit.

See [`docs/RESOURCE_SAFEGUARDS.md`](docs/RESOURCE_SAFEGUARDS.md) for parameter selection, verification commands and troubleshooting.

See [`docs/HOW_TO_USE.md`](docs/HOW_TO_USE.md) for complete setup, Jenkins configuration, parameter reference, operating steps, troubleshooting and IR evidence.

## 3. Service configuration

The reusable service map is defined in `Jenkinsfile` by `serviceConfiguration`. It maps each individual Jenkins service to:

- its repository URL parameter;
- image repository parameter;
- host and container port parameters;
- isolated source directory.

The shared Pipeline stages are reused by all three technologies. `SERVICE=all` expands to all service-map entries, checks out and tests the three repositories in parallel, assigns each image a build-and-commit tag, and sends the selected service list to Docker Compose. Unique host ports are required before any checkout or deployment begins.

## 4. Manual Docker verification

Copy the example environment file and replace its absolute source and Dockerfile paths:

```bash
cp .env.example .env
docker compose config --quiet
docker compose build go-backend
docker compose build react-frontend
docker compose build ruby-service
```

To deploy one service manually:

```bash
docker compose up --build -d react-frontend
docker compose ps
```

Remove the manual deployment with:

```bash
docker compose down
```

## 5. Local Docker server requirements

The internal Dev/QC server needs:

- Linux and Bash;
- Docker Engine and Docker Compose v2;
- an SSH deployment user with Docker access;
- `rsync`;
- a writable toolkit base directory.

Example preparation by an administrator:

```bash
sudo mkdir -p /opt/deployment-toolkit
sudo chown DEPLOYMENT_USER:DEPLOYMENT_USER /opt/deployment-toolkit
docker version
docker compose version
rsync --version
```

Docker access grants strong control over the server. Use a dedicated Dev/QC host and restrict the Jenkins credentials.

## 6. Jenkins requirements and credentials

The Jenkins agent labelled `docker` needs Git, Docker, Docker Compose, SSH and rsync. It also needs the **SSH Agent** and **Credentials Binding** plugins.

For private application repositories, configure a GitHub SSH credential and supply its Jenkins credential ID through `GIT_CREDENTIALS_ID`. Never store a private key or token in this repository.

Create the server authentication credential under **Manage Jenkins → Credentials → System → Global credentials**:

```text
Kind: SSH Username with private key
ID: local-server-ssh
Username: the real deployment user
Private key: dedicated server deployment key
```

Upload the verified SSH host-key file as:

```text
Kind: Secret file
ID: local-server-known-hosts
File: local-server-known_hosts
```

The Pipeline enforces strict host-key checking.

## 7. Jenkins job configuration

Create one **Pipeline script from SCM** job pointing to this toolkit repository and use `Jenkinsfile` as the script path. Use the integrated Dev/QC branch:

```text
*/develop
```

During development, temporarily point the job to the feature or fix branch being tested. Run the job once after changing the toolkit branch so Jenkins loads the updated parameters, then return it to `*/develop` after the PR is merged.

## 8. Go build or deployment

Use values matching the Go application:

| Parameter | Example |
|---|---|
| `SERVICE` | `go-backend` |
| `ACTION` | `build`, then `deploy` |
| `PROJECT_ID` | A reusable project slug, such as `customer-portal` |
| `GO_REPO_URL` | Go repository SSH URL |
| `GO_REPO_BRANCH` | `develop` |
| `GIT_CREDENTIALS_ID` | GitHub credential ID |
| `GO_BUILD_PACKAGE` | `.` or `./cmd/server` |
| `GO_VERSION` | Version compatible with `go.mod` |
| `GO_IMAGE_REPOSITORY` | `local/go-backend` |
| `GO_HOST_PORT` | `8081` |
| `GO_CONTAINER_PORT` | `8080` |
| `GO_RESTART_POLICY` | `unless-stopped` |
| `GO_MEMORY_LIMIT` | `256m` |
| `GO_CPU_LIMIT` | `0.50` |

The unused React and Ruby parameters may retain their defaults.

## 9. React build or deployment

Use values matching the React application:

| Parameter | Value |
|---|---|
| `SERVICE` | `react-frontend` |
| `ACTION` | `build`, then `deploy` |
| `PROJECT_ID` | The same project slug used by its related services |
| `REACT_REPO_URL` | React repository SSH or HTTPS URL |
| `REACT_REPO_BRANCH` | `develop` |
| `GIT_CREDENTIALS_ID` | Existing GitHub credential ID |
| `NODE_VERSION` | `22` |
| `NODE_BUILD_MEMORY_MB` | `768` |
| `REACT_IMAGE_REPOSITORY` | `local/react-frontend` |
| `REACT_HOST_PORT` | `3000` |
| `REACT_CONTAINER_PORT` | `80` |
| `REACT_RESTART_POLICY` | `unless-stopped` |
| `REACT_MEMORY_LIMIT` | `256m` |
| `REACT_CPU_LIMIT` | `0.50` |
| `LOCAL_SERVER_HOST` | Internal Dev/QC server address |
| `LOCAL_SERVER_USER` | Real SSH deployment user |
| `LOCAL_SERVER_BASE_DIR` | `/opt/deployment-toolkit` |
| `SSH_CREDENTIALS_ID` | `local-server-ssh` |
| `SSH_KNOWN_HOSTS_CREDENTIALS_ID` | `local-server-known-hosts` |

After `ACTION=deploy`, verify the React service from the Ubuntu server:

```bash
docker compose ps
curl http://localhost:3000/
```

React is served over HTTP, so `curl` is a valid runtime check.
The React container port remains `80` because that is the port used by the production Nginx runtime; change only the host port when avoiding a server-side conflict.

## 10. Ruby build or deployment

Use values matching the target Ruby service:

| Parameter | Value |
|---|---|
| `SERVICE` | `ruby-service` |
| `ACTION` | `build`, then `deploy` |
| `PROJECT_ID` | A reusable project slug, such as `customer-portal` |
| `RUBY_REPO_URL` | Ruby repository SSH or HTTPS URL |
| `RUBY_REPO_BRANCH` | `develop` |
| `GIT_CREDENTIALS_ID` | Blank for the public HTTPS repository |
| `RUBY_VERSION` | `3.4.5` |
| `RUBY_TEST_FILE` | `test/app_test.rb` |
| `RUBY_IMAGE_REPOSITORY` | `local/ruby-service` |
| `RUBY_HOST_PORT` | `9292` |
| `RUBY_CONTAINER_PORT` | `9292` |
| `RUBY_RESTART_POLICY` | `unless-stopped` |
| `RUBY_MEMORY_LIMIT` | `256m` |
| `RUBY_CPU_LIMIT` | `0.50` |

After `ACTION=deploy`, verify the Ruby service from the Ubuntu server:

```bash
curl http://localhost:9292/
curl http://localhost:9292/health
```

The Jenkins job also waits for the `/health` Docker health check and prints recent container logs if readiness fails.

## 11. Parallel multi-service build or deployment

Set `SERVICE=all` to process Go, React and Ruby in one Jenkins run. Supply all three repository URLs and branches, and keep the host ports unique. A suitable test sequence is:

```text
First run:  SERVICE=all, ACTION=build
Second run: SERVICE=all, ACTION=deploy
```

The pipeline performs these operations:

1. validates the three selected configurations and detects host-port collisions;
2. checks out the three application repositories in parallel;
3. runs Go, React and Ruby validation in parallel when `RUN_TESTS=true`;
4. synchronizes the three source trees into one isolated remote release;
5. invokes Docker Compose once with the `go`, `react` and `ruby` profiles;
6. records each image tag and size, then verifies every deployed container.

Parallel validation containers are each limited to `1g` memory, `1.0` CPU and 256 processes. Their temporary combined peak can therefore be higher than a single-service run. `disableConcurrentBuilds()` prevents two complete Jenkins jobs from consuming the Docker host simultaneously.

## 12. Releases and IR evidence

Every build creates an isolated remote directory:

```text
/opt/deployment-toolkit/projects/PROJECT_ID/releases/BUILD_NUMBER/
```

The Jenkins console records source checkout, validation, SSH transfer, Docker build, container state, image tag and image size. Record a manual baseline before claiming a percentage improvement, using the same service, commit, host and network conditions.

## 13. Next phase

After `SERVICE=all` build/deployment and single-service regressions succeed:

1. compare the measured all-service duration with the previous manual baseline;
2. record Jenkins checkout/build logs and Docker image sizes as IR evidence;
3. finalize rollback behavior and the Wiki usage guide;
4. consider a manifest-driven dynamic-service model only if projects need more than the current Go/React/Ruby slots.
