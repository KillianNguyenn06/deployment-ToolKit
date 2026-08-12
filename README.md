# Deployment Toolkit — Go SSH Pilot

This repository provides one parameterized Jenkins job for building or deploying a Go service on an internal Dev/QC Docker server over SSH. The application branch defaults to `develop` and the first target environment is `dev`.

```text
Jenkins agent
  -> checkout toolkit and Go source
  -> run Go tests
  -> rsync a unique release directory over SSH
  -> run Docker Compose on the local server
  -> verify the image and container over SSH
```

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

## 3. Prepare the local Docker server

The internal Dev/QC server needs:

- Linux with `bash`;
- Docker Engine and Docker Compose v2;
- an SSH user that can run Docker;
- `rsync`;
- a writable toolkit base directory.

Example server preparation, performed by an administrator:

```bash
sudo mkdir -p /opt/deployment-toolkit
sudo chown ubuntu:ubuntu /opt/deployment-toolkit
docker version
docker compose version
rsync --version
```

Replace `ubuntu` with the real deployment account. Giving an account Docker access grants strong control over that server, so use a dedicated Dev/QC host and restrict SSH/Jenkins permissions.

## 4. Prepare Jenkins

The Jenkins agent labelled `docker` needs:

- Git;
- Docker Engine;
- Docker Compose v2 (`docker compose`);
- an SSH client and `rsync`;
- permission for the Jenkins agent account to access the Docker daemon;
- network access to Git repositories and the local server's SSH port;
- the **SSH Agent** and **Credentials Binding** Jenkins plugins.

Docker is used on the agent to test the Go source. The application image is built on the remote local server.

For a private Git repository, create a Jenkins credential and remember its credential ID. Do not store passwords, private keys, or tokens in this repository.

### SSH authentication credential

In **Manage Jenkins → Credentials → System → Global credentials**, add:

```text
Kind: SSH Username with private key
ID: local-server-ssh
Username: ubuntu (or the real deployment user)
Private key: the dedicated deployment private key
```

Install the matching public key in the deployment user's `~/.ssh/authorized_keys` on the local server.

### Verified host-key credential

On a trusted administrator machine, obtain the server host key:

```bash
ssh-keyscan -H YOUR_LOCAL_SERVER_HOST > local-server-known_hosts
ssh-keygen -lf local-server-known_hosts
```

Verify the displayed fingerprint with the server administrator before using it. Upload the file to Jenkins as:

```text
Kind: Secret file
ID: local-server-known-hosts
File: local-server-known_hosts
```

The pipeline uses strict host-key checking. It does not automatically trust an unknown server.

## 5. Create the Jenkins job

1. Push this toolkit directory to its own Git repository.
2. In Jenkins, select **New Item**.
3. Choose **Pipeline**.
4. Under **Pipeline**, choose **Pipeline script from SCM**.
5. Select Git and enter the Deployment Toolkit repository URL.
6. Set the script path to `Jenkinsfile`.
7. Save, then run the job once so Jenkins loads the parameters.

In **Manage Jenkins → Nodes**, ensure the machine that has Docker is available as an agent with the label `docker`. The pipeline deliberately does not run on an arbitrary Jenkins node.

For this feature branch test, set the toolkit SCM branch to:

```text
*/feature/ssh-local-server-deploy
```

After review and merge, change it back to `*/develop`.

## 6. Run the Go SSH pilot

Use these first-run values:

| Parameter | Initial value |
|---|---|
| `SERVICE` | `go-backend` |
| `ACTION` | `build` |
| `BRANCH` | `develop` |
| `ENVIRONMENT` | `dev` |
| `PROJECT_ID` | `calendar` or another lowercase project slug |
| `GO_REPO_URL` | URL of the Go repository |
| `GIT_CREDENTIALS_ID` | Jenkins credential ID, or blank for a public repository |
| `GO_BUILD_PACKAGE` | `./cmd/server`, adjusted to the real project |
| `GO_VERSION` | Version compatible with the application's `go.mod` |
| `IMAGE_REPOSITORY` | `local/go-backend` |
| `HOST_PORT` | An unused port on the local Docker server, such as `8080` |
| `CONTAINER_PORT` | The application's listening port, such as `8080` |
| `LOCAL_SERVER_HOST` | Internal Dev/QC server hostname or IPv4 address |
| `LOCAL_SERVER_USER` | `ubuntu` or the real SSH deployment user |
| `LOCAL_SERVER_BASE_DIR` | `/opt/deployment-toolkit` |
| `SSH_CREDENTIALS_ID` | `local-server-ssh` |
| `SSH_KNOWN_HOSTS_CREDENTIALS_ID` | `local-server-known-hosts` |

Run `ACTION=build` first. When it succeeds, run the same parameters with `ACTION=deploy`.

Each build uses an isolated remote release directory:

```text
/opt/deployment-toolkit/projects/PROJECT_ID/releases/BUILD_NUMBER/
```

`ACTION=build` builds the image on the local server without starting it. `ACTION=deploy` builds the image and starts or updates the Compose service.

## 7. Evidence for the IR

The pipeline console records:

- toolkit and application checkout;
- `go test ./...` results;
- transfer of the release to the local server;
- the remote Docker/Compose build;
- the remote container state;
- the final image tag and size in bytes;
- `docker image ls` output.

Record a manual deployment baseline before claiming a percentage improvement. Compare the same service, host class, network conditions, and application commit.

## 8. Next phase

After the Go pilot is stable:

1. add React and Ruby Dockerfiles;
2. add their services to `compose.yaml`;
3. extend `SERVICE` to `go-backend`, `react-frontend`, `ruby-service`, and `all`;
4. place repository/build settings in a centralized service configuration;
5. add health endpoints and rollback rules before deploying beyond Dev.
