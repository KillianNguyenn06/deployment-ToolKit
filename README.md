# Deployment Toolkit — Go and React SSH deployment

This repository provides one parameterized Jenkins Pipeline for building or deploying a Go backend or React frontend on an internal Dev/QC Docker server over SSH. Application repositories remain separate from the deployment logic.

```text
Jenkins parameters
  -> select Go or React configuration
  -> checkout toolkit and selected application repository
  -> run technology-specific validation
  -> rsync an isolated release over SSH
  -> build or deploy the selected Compose service
  -> verify the image and container
```

## 1. Application contracts

### Go

The Go repository must:

- contain `go.mod` at its root (`go.sum` is optional);
- compile with `CGO_ENABLED=0`;
- expose one buildable package, configured with `GO_BUILD_PACKAGE`;
- use the `PORT` environment variable if it is a web service.

The final image uses a distroless non-root runtime. A CLI application can be verified through its container process and logs instead of HTTP.
CLI deployments default to `GO_RESTART_POLICY=no`, so an infinite-loop utility does not automatically return after Docker or the host restarts.

### React

The React repository must:

- contain `package.json` and `package-lock.json` at its root;
- support `npm run lint` for Jenkins validation;
- support `npm run build`;
- produce static production files in `dist/`.

The build stage uses Node.js. The final image contains only Nginx and the generated `dist/` files.
`NODE_BUILD_MEMORY_MB` caps the Node.js heap during linting and production builds.

## 2. Resource and storage safeguards

Every deployed service has explicit CPU, memory and process limits. Docker JSON logs rotate at `10m` with three files by default, preventing an application that prints continuously from filling the server disk.

After a successful build or deployment, the toolkit:

- retains only the newest `RELEASE_RETENTION` numbered release directories, default `5`;
- removes unused toolkit-managed images older than `IMAGE_RETENTION_HOURS`, default `72`;
- removes unused Docker build cache older than `BUILD_CACHE_RETENTION_HOURS`, default `168`, when `PRUNE_BUILD_CACHE=true`;
- lets Jenkins retain 20 build records and 10 artifact sets.

Image cleanup is restricted through toolkit and project labels. Build-cache cleanup is Docker-host-wide but only removes unused cache older than the configured threshold; disable it on a shared builder by setting `PRUNE_BUILD_CACHE=false`.

These settings apply when Compose creates or recreates a container. They do not retroactively limit an already-running container created by an earlier version of the toolkit.

## 3. Service configuration

The reusable service map is defined in `Jenkinsfile` by `serviceConfiguration`. It maps each Jenkins `SERVICE` value to:

- its repository URL parameter;
- image repository parameter;
- host and container port parameters;
- isolated source directory.

The shared Pipeline stages do not need to be copied for each technology. Ruby and multi-service execution will be added after both Go and React paths are verified.

## 4. Manual Docker verification

Copy the example environment file and replace its absolute source and Dockerfile paths:

```bash
cp .env.example .env
docker compose config --quiet
docker compose build go-backend
docker compose build react-frontend
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

Create one **Pipeline script from SCM** job pointing to this toolkit repository and use `Jenkinsfile` as the script path.

During Phase 3 testing, configure its toolkit branch as:

```text
*/feature/react-service-deploy
```

After review and merge, switch the job back to:

```text
*/develop
```

Run the job once after changing the toolkit branch so Jenkins loads the updated parameters.

## 8. Go build or deployment

Use values matching the Go application:

| Parameter | Example |
|---|---|
| `SERVICE` | `go-backend` |
| `ACTION` | `build`, then `deploy` |
| `PROJECT_ID` | `calendar` |
| `GO_REPO_URL` | Go repository SSH URL |
| `GO_REPO_BRANCH` | `develop` |
| `GIT_CREDENTIALS_ID` | GitHub credential ID |
| `GO_BUILD_PACKAGE` | `.` or `./cmd/server` |
| `GO_VERSION` | Version compatible with `go.mod` |
| `GO_IMAGE_REPOSITORY` | `local/calendar` |
| `GO_HOST_PORT` | `8081` |
| `GO_CONTAINER_PORT` | `8080` |
| `GO_RESTART_POLICY` | `no` for the Calendar CLI |
| `GO_MEMORY_LIMIT` | `256m` |
| `GO_CPU_LIMIT` | `0.50` |

The unused React parameters may retain their defaults.

## 9. React build or deployment

Use these initial values for the employee directory:

| Parameter | Value |
|---|---|
| `SERVICE` | `react-frontend` |
| `ACTION` | `build`, then `deploy` |
| `PROJECT_ID` | `employee-directory` |
| `REACT_REPO_URL` | `git@github.com:KillianNguyenn06/employee-directory.git` |
| `REACT_REPO_BRANCH` | `develop` |
| `GIT_CREDENTIALS_ID` | Existing GitHub credential ID |
| `NODE_VERSION` | `22` |
| `NODE_BUILD_MEMORY_MB` | `768` |
| `REACT_IMAGE_REPOSITORY` | `local/employee-directory` |
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

Unlike the CLI Go pilot, React is served over HTTP, so `curl` is a valid runtime check.
The React container port remains `80` because that is the port used by the production Nginx runtime; change only the host port when avoiding a server-side conflict.

## 10. Releases and IR evidence

Every build creates an isolated remote directory:

```text
/opt/deployment-toolkit/projects/PROJECT_ID/releases/BUILD_NUMBER/
```

The Jenkins console records source checkout, validation, SSH transfer, Docker build, container state, image tag and image size. Record a manual baseline before claiming a percentage improvement, using the same service, commit, host and network conditions.

## 11. Next phase

After Go regression testing and React build/deployment succeed:

1. add the Ruby service configuration and Dockerfile;
2. add `SERVICE=all`;
3. check out multiple repositories and build independent services in parallel;
4. add health checks, retention/cleanup and rollback behavior;
5. finalize measurements and the Wiki guide.
