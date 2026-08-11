# Deployment Toolkit — Phase 1

This repository provides one parameterized Jenkins job for building or deploying a Go service. The default application branch is `develop`, and the first target environment is `dev`.

## 1. Application contract

The Go repository must:

- contain `go.mod` at its root (`go.sum` is used when present);
- compile with `CGO_ENABLED=0`;
- expose one buildable package, defaulting to `./cmd/server`;
- listen on the port supplied through the `PORT` environment variable, default `8080`.

If the application uses a different main package, set `GO_BUILD_PACKAGE` in Jenkins.

## 2. Verify Docker manually first

Copy the example environment file and replace the source paths with absolute paths:

```bash
cp .env.example .env
docker compose config --quiet
docker compose build go-backend
docker compose up -d go-backend
docker compose ps
docker image ls local/go-backend
```

Stop the manual deployment with:

```bash
docker compose down
```

## 3. Prepare Jenkins

The Jenkins controller may be separate, but the agent labelled `docker` needs:

- Git;
- Docker Engine;
- Docker Compose v2 (`docker compose`);
- permission for the Jenkins agent account to access the Docker daemon;
- network access to the Git repository and required container registries.

Using Docker access gives the Jenkins agent control over the Docker host. Use a dedicated agent and protect access to the Jenkins job.

For a private Git repository, create a Jenkins credential and remember its credential ID. Do not store passwords, private keys, or tokens in this repository.

## 4. Create the Jenkins job

1. Push this toolkit directory to its own Git repository.
2. In Jenkins, select **New Item**.
3. Choose **Pipeline**.
4. Under **Pipeline**, choose **Pipeline script from SCM**.
5. Select Git and enter the Deployment Toolkit repository URL.
6. Set the script path to `Jenkinsfile`.
7. Save, then run the job once so Jenkins loads the parameters.

In **Manage Jenkins → Nodes**, ensure the machine that has Docker is available as an agent with the label `docker`. The pipeline deliberately does not run on an arbitrary Jenkins node.

## 5. Run the Go pilot

Use these first-run values:

| Parameter | Initial value |
|---|---|
| `SERVICE` | `go-backend` |
| `ACTION` | `build` |
| `BRANCH` | `develop` |
| `ENVIRONMENT` | `dev` |
| `GO_REPO_URL` | URL of the Go repository |
| `GIT_CREDENTIALS_ID` | Jenkins credential ID, or blank for a public repository |
| `GO_BUILD_PACKAGE` | `./cmd/server`, adjusted to the real project |
| `GO_VERSION` | Version compatible with the application's `go.mod` |
| `IMAGE_REPOSITORY` | `local/go-backend` |
| `HOST_PORT` | An unused host port, such as `8081` when Jenkins uses `8080` |
| `CONTAINER_PORT` | The application's listening port, such as `8080` |

Run `ACTION=build` first. When it succeeds, run the same parameters with `ACTION=deploy`.

## 6. Evidence for the IR

The pipeline console records:

- toolkit and application checkout;
- `go test ./...` results;
- the Docker/Compose build;
- the deployed container state;
- the final image tag and size in bytes;
- `docker image ls` output.

Record a manual deployment baseline before claiming a percentage improvement. Compare the same service, host class, network conditions, and application commit.

## 7. Next phase

After the Go pilot is stable:

1. add React and Ruby Dockerfiles;
2. add their services to `compose.yaml`;
3. extend `SERVICE` to `go-backend`, `react-frontend`, `ruby-service`, and `all`;
4. place repository/build settings in a centralized service configuration;
5. add health endpoints and rollback rules before deploying beyond Dev.
