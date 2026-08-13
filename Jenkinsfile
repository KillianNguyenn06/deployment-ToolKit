pipeline {
    agent { label 'docker' }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    parameters {
        choice(
            name: 'SERVICE',
            choices: ['go-backend', 'react-frontend'],
            description: 'Application service to build or deploy.'
        )
        choice(
            name: 'ACTION',
            choices: ['build', 'deploy'],
            description: 'build creates an image; deploy also starts or updates the container.'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev'],
            description: 'Target environment.'
        )
        string(
            name: 'PROJECT_ID',
            defaultValue: '',
            description: 'Lowercase project slug used to isolate remote releases and Compose resources.'
        )
        string(
            name: 'GO_REPO_URL',
            defaultValue: '',
            description: 'HTTPS or SSH URL of the Go application repository.'
        )
        string(
            name: 'GO_REPO_BRANCH',
            defaultValue: 'develop',
            description: 'Branch in the Go application repository. Blank falls back to develop.'
        )
        string(
            name: 'REACT_REPO_URL',
            defaultValue: '',
            description: 'HTTPS or SSH URL of the React application repository.'
        )
        string(
            name: 'REACT_REPO_BRANCH',
            defaultValue: 'develop',
            description: 'Branch in the React application repository. Blank falls back to develop.'
        )
        string(
            name: 'GIT_CREDENTIALS_ID',
            defaultValue: '',
            description: 'Optional Jenkins credential ID shared by private application repositories.'
        )
        string(
            name: 'GO_BUILD_PACKAGE',
            defaultValue: './cmd/server',
            description: 'Go package that produces the application binary.'
        )
        string(
            name: 'GO_VERSION',
            defaultValue: '1.25',
            description: 'Go builder image version compatible with go.mod.'
        )
        string(
            name: 'GO_IMAGE_REPOSITORY',
            defaultValue: 'local/go-backend',
            description: 'Go Docker image repository/name, without the tag.'
        )
        string(
            name: 'GO_HOST_PORT',
            defaultValue: '8081',
            description: 'Host port used by the Go service.'
        )
        string(
            name: 'GO_CONTAINER_PORT',
            defaultValue: '8080',
            description: 'Port used by a long-running Go web service inside its container.'
        )
        choice(
            name: 'GO_RESTART_POLICY',
            choices: ['no', 'on-failure', 'unless-stopped'],
            description: 'Use no for CLI programs; use unless-stopped only for long-running services.'
        )
        string(
            name: 'GO_MEMORY_LIMIT',
            defaultValue: '256m',
            description: 'Maximum runtime memory for the Go container.'
        )
        string(
            name: 'GO_CPU_LIMIT',
            defaultValue: '0.50',
            description: 'Maximum CPU cores for the Go container.'
        )
        string(
            name: 'NODE_VERSION',
            defaultValue: '22',
            description: 'Node.js major or full version used to build React.'
        )
        string(
            name: 'NODE_BUILD_MEMORY_MB',
            defaultValue: '768',
            description: 'Maximum Node.js heap size used while linting and building React.'
        )
        string(
            name: 'REACT_IMAGE_REPOSITORY',
            defaultValue: 'local/react-frontend',
            description: 'React Docker image repository/name, without the tag.'
        )
        string(
            name: 'REACT_HOST_PORT',
            defaultValue: '3000',
            description: 'Host port used to access the React application.'
        )
        string(
            name: 'REACT_CONTAINER_PORT',
            defaultValue: '80',
            description: 'Nginx port inside the React container.'
        )
        choice(
            name: 'REACT_RESTART_POLICY',
            choices: ['unless-stopped', 'on-failure', 'no'],
            description: 'Restart behavior for the React web container.'
        )
        string(
            name: 'REACT_MEMORY_LIMIT',
            defaultValue: '256m',
            description: 'Maximum runtime memory for the React/Nginx container.'
        )
        string(
            name: 'REACT_CPU_LIMIT',
            defaultValue: '0.50',
            description: 'Maximum CPU cores for the React/Nginx container.'
        )
        string(
            name: 'DOCKER_LOG_MAX_SIZE',
            defaultValue: '10m',
            description: 'Maximum size of one Docker JSON log file before rotation.'
        )
        string(
            name: 'DOCKER_LOG_MAX_FILES',
            defaultValue: '3',
            description: 'Number of rotated Docker log files retained per container.'
        )
        string(
            name: 'RELEASE_RETENTION',
            defaultValue: '5',
            description: 'Number of remote release directories retained per project.'
        )
        string(
            name: 'IMAGE_RETENTION_HOURS',
            defaultValue: '72',
            description: 'Unused toolkit-managed images older than this are removed after success.'
        )
        booleanParam(
            name: 'PRUNE_BUILD_CACHE',
            defaultValue: true,
            description: 'Remove unused Docker build cache older than BUILD_CACHE_RETENTION_HOURS after success.'
        )
        string(
            name: 'BUILD_CACHE_RETENTION_HOURS',
            defaultValue: '168',
            description: 'Age threshold for unused Docker build cache cleanup.'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run the selected service validation before building or deploying.'
        )
        string(
            name: 'LOCAL_SERVER_HOST',
            defaultValue: '',
            description: 'Internal Dev/QC Docker server hostname or IPv4 address.'
        )
        string(
            name: 'LOCAL_SERVER_USER',
            defaultValue: '',
            description: 'SSH user on the local Docker server.'
        )
        string(
            name: 'LOCAL_SERVER_BASE_DIR',
            defaultValue: '/opt/deployment-toolkit',
            description: 'Base deployment directory on the local Docker server.'
        )
        string(
            name: 'SSH_CREDENTIALS_ID',
            defaultValue: 'local-server-ssh',
            description: 'Jenkins SSH Username with private key credential ID.'
        )
        string(
            name: 'SSH_KNOWN_HOSTS_CREDENTIALS_ID',
            defaultValue: 'local-server-known-hosts',
            description: 'Jenkins Secret file credential ID containing the verified server host key.'
        )
    }

    environment {
        TOOLKIT_DIR = "${WORKSPACE}"
        COMPOSE_FILE = "${WORKSPACE}/compose.yaml"
    }

    stages {
        stage('Validate parameters') {
            steps {
                script {
                    def service = serviceConfiguration(params.SERVICE)
                    env.APP_BRANCH = params[service.branchParameter].trim() ?: 'develop'
                    env.APP_REPO_URL = params[service.repoParameter].trim()
                    env.SOURCE_SUBDIR = service.sourceSubdir
                    env.SOURCE_DIR = "${env.WORKSPACE}/sources/${service.sourceSubdir}"
                    env.TARGET_IMAGE_REPOSITORY = params[service.imageParameter].trim()

                    if (!env.APP_REPO_URL) {
                        error("${service.repoParameter} is required when SERVICE=${params.SERVICE}.")
                    }
                    if (!(params.PROJECT_ID ==~ /[a-z0-9][a-z0-9-]{1,62}/)) {
                        error('PROJECT_ID must be 2-63 lowercase letters, numbers, or hyphens.')
                    }
                    if (!(params.LOCAL_SERVER_HOST ==~ /[A-Za-z0-9.-]+/)) {
                        error('LOCAL_SERVER_HOST must be a hostname or IPv4 address.')
                    }
                    if (!(params.LOCAL_SERVER_USER ==~ /[A-Za-z_][A-Za-z0-9_-]*/)) {
                        error('LOCAL_SERVER_USER contains unsupported characters.')
                    }
                    if (!(params.LOCAL_SERVER_BASE_DIR ==~ /\/[A-Za-z0-9._\/-]+/)) {
                        error('LOCAL_SERVER_BASE_DIR must be a safe absolute path without spaces.')
                    }
                    if (!params.SSH_CREDENTIALS_ID.trim() || !params.SSH_KNOWN_HOSTS_CREDENTIALS_ID.trim()) {
                        error('Both SSH credential IDs are required.')
                    }
                    if (!(env.APP_BRANCH ==~ /[A-Za-z0-9._\/-]+/)) {
                        error("${service.branchParameter} contains unsupported characters.")
                    }
                    if (!(params.GO_BUILD_PACKAGE ==~ /[A-Za-z0-9._\/-]+/)) {
                        error('GO_BUILD_PACKAGE contains unsupported characters.')
                    }
                    ['GO_IMAGE_REPOSITORY', 'REACT_IMAGE_REPOSITORY'].each { parameterName ->
                        if (!(params[parameterName] ==~ /[A-Za-z0-9._\/-]+/)) {
                            error("${parameterName} contains unsupported characters.")
                        }
                    }
                    validateVersion(params.GO_VERSION, 'GO_VERSION')
                    validateVersion(params.NODE_VERSION, 'NODE_VERSION')
                    ['GO_HOST_PORT', 'GO_CONTAINER_PORT', 'REACT_HOST_PORT', 'REACT_CONTAINER_PORT'].each { parameterName ->
                        validatePort(params[parameterName], parameterName)
                    }
                    if (params.REACT_CONTAINER_PORT != '80') {
                        error('REACT_CONTAINER_PORT must be 80 because the production Nginx image listens on port 80.')
                    }
                    ['GO_MEMORY_LIMIT', 'REACT_MEMORY_LIMIT'].each { parameterName ->
                        if (!(params[parameterName] ==~ /[1-9][0-9]*[kKmMgG]/)) {
                            error("${parameterName} must be a positive Docker memory value such as 256m or 1g.")
                        }
                    }
                    ['GO_CPU_LIMIT', 'REACT_CPU_LIMIT'].each { parameterName ->
                        def cpuValue = params[parameterName]
                        def isNumeric = cpuValue ==~ /[0-9]+(\.[0-9]+)?/
                        def isZero = cpuValue ==~ /0+(\.0+)?/
                        if (!isNumeric || isZero) {
                            error("${parameterName} must be a positive CPU number such as 0.50 or 1.")
                        }
                    }
                    if (!(params.DOCKER_LOG_MAX_SIZE ==~ /[1-9][0-9]*[kKmMgG]/)) {
                        error('DOCKER_LOG_MAX_SIZE must be a positive size such as 10m.')
                    }
                    validatePositiveInteger(params.DOCKER_LOG_MAX_FILES, 'DOCKER_LOG_MAX_FILES', 10)
                    validatePositiveInteger(params.RELEASE_RETENTION, 'RELEASE_RETENTION', 100)
                    validatePositiveInteger(params.IMAGE_RETENTION_HOURS, 'IMAGE_RETENTION_HOURS', 8760)
                    validatePositiveInteger(params.BUILD_CACHE_RETENTION_HOURS, 'BUILD_CACHE_RETENTION_HOURS', 8760)
                    validatePositiveInteger(params.NODE_BUILD_MEMORY_MB, 'NODE_BUILD_MEMORY_MB', 8192)

                    env.REMOTE_RELEASE_DIR = "${params.LOCAL_SERVER_BASE_DIR}/projects/${params.PROJECT_ID}/releases/${env.BUILD_NUMBER}"
                }

                sh '''
                    set -eu
                    docker version
                    docker compose version
                    ssh -V
                    rsync --version
                '''
            }
        }

        stage('Checkout toolkit') {
            steps {
                checkout scm
            }
        }

        stage('Checkout application') {
            steps {
                dir(env.SOURCE_DIR) {
                    deleteDir()
                    script {
                        def remote = [url: env.APP_REPO_URL]
                        if (params.GIT_CREDENTIALS_ID.trim()) {
                            remote.credentialsId = params.GIT_CREDENTIALS_ID.trim()
                        }

                        checkout([
                            $class: 'GitSCM',
                            branches: [[name: "*/${env.APP_BRANCH}"]],
                            userRemoteConfigs: [remote]
                        ])

                        env.GIT_COMMIT_SHORT = sh(
                            script: 'git rev-parse --short=12 HEAD',
                            returnStdout: true
                        ).trim()
                        env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    }
                }
            }
        }

        stage('Test application') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    if (params.SERVICE == 'go-backend') {
                        sh '''
                            set -eu
                            docker run --rm \
                                --memory=1g \
                                --cpus=1.0 \
                                --pids-limit=256 \
                                -v "$SOURCE_DIR:/src:ro" \
                                -w /src \
                                "golang:$GO_VERSION-bookworm" \
                                go test ./...
                        '''
                    } else if (params.SERVICE == 'react-frontend') {
                        sh '''
                            set -eu
                            docker run --rm \
                                --memory=1g \
                                --cpus=1.0 \
                                --pids-limit=256 \
                                -e "NODE_OPTIONS=--max-old-space-size=$NODE_BUILD_MEMORY_MB" \
                                -v "$SOURCE_DIR:/source:ro" \
                                "node:$NODE_VERSION-bookworm-slim" \
                                sh -c 'cp -a /source/. /tmp/app && cd /tmp/app && npm ci && npm run lint && npm run build'
                        '''
                    }
                }
            }
        }

        stage('Validate Compose') {
            steps {
                withEnv(composeEnvironment()) {
                    sh 'docker compose --file "$COMPOSE_FILE" config --quiet'
                }
            }
        }

        stage('Prepare remote configuration') {
            steps {
                script {
                    writeFile file: '.env.remote', text: """\
SERVICE=${params.SERVICE}
GO_SOURCE_DIR=${env.REMOTE_RELEASE_DIR}/sources/go-backend
GO_DOCKERFILE=${env.REMOTE_RELEASE_DIR}/docker/go.Dockerfile
GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}
GO_VERSION=${params.GO_VERSION}
GO_IMAGE_REPOSITORY=${params.GO_IMAGE_REPOSITORY}
GO_HOST_PORT=${params.GO_HOST_PORT}
GO_CONTAINER_PORT=${params.GO_CONTAINER_PORT}
GO_RESTART_POLICY=${params.GO_RESTART_POLICY}
GO_MEMORY_LIMIT=${params.GO_MEMORY_LIMIT}
GO_CPU_LIMIT=${params.GO_CPU_LIMIT}
REACT_SOURCE_DIR=${env.REMOTE_RELEASE_DIR}/sources/react-frontend
REACT_DOCKERFILE=${env.REMOTE_RELEASE_DIR}/docker/react.Dockerfile
NODE_VERSION=${params.NODE_VERSION}
NODE_BUILD_MEMORY_MB=${params.NODE_BUILD_MEMORY_MB}
REACT_IMAGE_REPOSITORY=${params.REACT_IMAGE_REPOSITORY}
REACT_HOST_PORT=${params.REACT_HOST_PORT}
REACT_CONTAINER_PORT=${params.REACT_CONTAINER_PORT}
REACT_RESTART_POLICY=${params.REACT_RESTART_POLICY}
REACT_MEMORY_LIMIT=${params.REACT_MEMORY_LIMIT}
REACT_CPU_LIMIT=${params.REACT_CPU_LIMIT}
DOCKER_LOG_MAX_SIZE=${params.DOCKER_LOG_MAX_SIZE}
DOCKER_LOG_MAX_FILES=${params.DOCKER_LOG_MAX_FILES}
RELEASE_RETENTION=${params.RELEASE_RETENTION}
IMAGE_RETENTION_HOURS=${params.IMAGE_RETENTION_HOURS}
PRUNE_BUILD_CACHE=${params.PRUNE_BUILD_CACHE}
BUILD_CACHE_RETENTION_HOURS=${params.BUILD_CACHE_RETENTION_HOURS}
TARGET_IMAGE_REPOSITORY=${env.TARGET_IMAGE_REPOSITORY}
IMAGE_TAG=${env.IMAGE_TAG}
APP_ENV=${params.ENVIRONMENT}
COMPOSE_PROJECT_NAME=${params.PROJECT_ID}-${params.ENVIRONMENT}
"""
                }
            }
        }

        stage('Sync release to local server') {
            steps {
                sshagent(credentials: [params.SSH_CREDENTIALS_ID]) {
                    withCredentials([file(
                        credentialsId: params.SSH_KNOWN_HOSTS_CREDENTIALS_ID,
                        variable: 'SSH_KNOWN_HOSTS'
                    )]) {
                        sh '''
                        set -eu
                        target="$LOCAL_SERVER_USER@$LOCAL_SERVER_HOST"

                        ssh \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=yes \
                            -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
                            "$target" \
                            "command -v rsync >/dev/null && docker version && docker compose version && mkdir -p '$REMOTE_RELEASE_DIR/sources/$SOURCE_SUBDIR'"

                        rsync -az \
                            --exclude='.git/' \
                            --exclude='.env' \
                            --exclude='.env.remote' \
                            --exclude='sources/' \
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$WORKSPACE/" \
                            "$target:$REMOTE_RELEASE_DIR/"

                        rsync -az \
                            --exclude='.git/' \
                            --exclude='node_modules/' \
                            --exclude='dist/' \
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$SOURCE_DIR/" \
                            "$target:$REMOTE_RELEASE_DIR/sources/$SOURCE_SUBDIR/"

                        rsync -az \
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$WORKSPACE/.env.remote" \
                            "$target:$REMOTE_RELEASE_DIR/.env"
                        '''
                    }
                }
            }
        }

        stage('Build or deploy on local server') {
            steps {
                sshagent(credentials: [params.SSH_CREDENTIALS_ID]) {
                    withCredentials([file(
                        credentialsId: params.SSH_KNOWN_HOSTS_CREDENTIALS_ID,
                        variable: 'SSH_KNOWN_HOSTS'
                    )]) {
                        sh '''
                        set -eu
                        target="$LOCAL_SERVER_USER@$LOCAL_SERVER_HOST"

                        ssh \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=yes \
                            -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
                            "$target" \
                            "cd '$REMOTE_RELEASE_DIR' && ENV_FILE='$REMOTE_RELEASE_DIR/.env' bash scripts/deploy.sh '$ACTION'"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'compose.yaml,docker/**,scripts/**,.env.remote', allowEmptyArchive: true
        }
        failure {
            echo 'Pipeline failed. Review the failed stage and Jenkins console output.'
        }
    }
}

def serviceConfiguration(String serviceName) {
    def services = [
        'go-backend': [
            repoParameter: 'GO_REPO_URL',
            branchParameter: 'GO_REPO_BRANCH',
            imageParameter: 'GO_IMAGE_REPOSITORY',
            sourceSubdir: 'go-backend'
        ],
        'react-frontend': [
            repoParameter: 'REACT_REPO_URL',
            branchParameter: 'REACT_REPO_BRANCH',
            imageParameter: 'REACT_IMAGE_REPOSITORY',
            sourceSubdir: 'react-frontend'
        ]
    ]

    if (!services.containsKey(serviceName)) {
        error("Unsupported SERVICE: ${serviceName}")
    }
    return services[serviceName]
}

def validateVersion(String value, String parameterName) {
    if (!(value ==~ /[0-9]+(\.[0-9]+){0,2}/)) {
        error("${parameterName} must be a numeric version such as 22, 22.4, or 22.4.1.")
    }
}

def validatePort(String value, String parameterName) {
    if (!(value ==~ /[0-9]+/)) {
        error("${parameterName} must be numeric.")
    }
    def port = value.toInteger()
    if (port < 1 || port > 65535) {
        error("${parameterName} must be between 1 and 65535.")
    }
}

def validatePositiveInteger(String value, String parameterName, Integer maximum) {
    if (!(value ==~ /[1-9][0-9]*/)) {
        error("${parameterName} must be a positive whole number.")
    }
    if (value.toInteger() > maximum) {
        error("${parameterName} must not exceed ${maximum}.")
    }
}

def composeEnvironment() {
    return [
        "SERVICE=${params.SERVICE}",
        "APP_ENV=${params.ENVIRONMENT}",
        "GO_SOURCE_DIR=${env.WORKSPACE}/sources/go-backend",
        "GO_DOCKERFILE=${env.WORKSPACE}/docker/go.Dockerfile",
        "GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}",
        "GO_VERSION=${params.GO_VERSION}",
        "GO_IMAGE_REPOSITORY=${params.GO_IMAGE_REPOSITORY}",
        "GO_HOST_PORT=${params.GO_HOST_PORT}",
        "GO_CONTAINER_PORT=${params.GO_CONTAINER_PORT}",
        "GO_RESTART_POLICY=${params.GO_RESTART_POLICY}",
        "GO_MEMORY_LIMIT=${params.GO_MEMORY_LIMIT}",
        "GO_CPU_LIMIT=${params.GO_CPU_LIMIT}",
        "REACT_SOURCE_DIR=${env.WORKSPACE}/sources/react-frontend",
        "REACT_DOCKERFILE=${env.WORKSPACE}/docker/react.Dockerfile",
        "NODE_VERSION=${params.NODE_VERSION}",
        "NODE_BUILD_MEMORY_MB=${params.NODE_BUILD_MEMORY_MB}",
        "REACT_IMAGE_REPOSITORY=${params.REACT_IMAGE_REPOSITORY}",
        "REACT_HOST_PORT=${params.REACT_HOST_PORT}",
        "REACT_CONTAINER_PORT=${params.REACT_CONTAINER_PORT}",
        "REACT_RESTART_POLICY=${params.REACT_RESTART_POLICY}",
        "REACT_MEMORY_LIMIT=${params.REACT_MEMORY_LIMIT}",
        "REACT_CPU_LIMIT=${params.REACT_CPU_LIMIT}",
        "DOCKER_LOG_MAX_SIZE=${params.DOCKER_LOG_MAX_SIZE}",
        "DOCKER_LOG_MAX_FILES=${params.DOCKER_LOG_MAX_FILES}",
        "TARGET_IMAGE_REPOSITORY=${env.TARGET_IMAGE_REPOSITORY}",
        "IMAGE_TAG=${env.IMAGE_TAG}",
        "COMPOSE_PROJECT_NAME=${params.PROJECT_ID}-${params.ENVIRONMENT}"
    ]
}
