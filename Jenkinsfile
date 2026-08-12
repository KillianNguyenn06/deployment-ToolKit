pipeline {
    agent { label 'docker' }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'SERVICE',
            choices: ['go-backend'],
            description: 'Service to build or deploy. React, Ruby, and all are added after the Go pilot is verified.'
        )
        choice(
            name: 'ACTION',
            choices: ['build', 'deploy'],
            description: 'build creates an image; deploy also starts or updates the container.'
        )
        string(
            name: 'BRANCH',
            defaultValue: 'develop',
            description: 'Application branch. Blank also falls back to develop.'
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
            name: 'GIT_CREDENTIALS_ID',
            defaultValue: '',
            description: 'Optional Jenkins credential ID for a private repository.'
        )
        string(
            name: 'GO_BUILD_PACKAGE',
            defaultValue: './cmd/server',
            description: 'Go package that produces the server binary.'
        )
        string(
            name: 'GO_VERSION',
            defaultValue: '1.25',
            description: 'Go builder image version. Set this to a version compatible with go.mod.'
        )
        string(
            name: 'IMAGE_REPOSITORY',
            defaultValue: 'local/go-backend',
            description: 'Docker image repository/name, without the tag.'
        )
        string(
            name: 'HOST_PORT',
            defaultValue: '8081',
            description: 'Host port used when ACTION=deploy.'
        )
        string(
            name: 'CONTAINER_PORT',
            defaultValue: '8080',
            description: 'Port on which the Go application listens inside the container.'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run go test ./... before building or deploying.'
        )
        string(
            name: 'LOCAL_SERVER_HOST',
            defaultValue: '',
            description: 'Internal Dev/QC Docker server hostname or IPv4 address.'
        )
        string(
            name: 'LOCAL_SERVER_USER',
            defaultValue: 'ubuntu',
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
        SOURCE_DIR = "${WORKSPACE}/sources/go-backend"
        COMPOSE_FILE = "${WORKSPACE}/compose.yaml"
        GO_DOCKERFILE = "${WORKSPACE}/docker/go.Dockerfile"
    }

    stages {
        stage('Validate parameters') {
            steps {
                script {
                    env.APP_BRANCH = params.BRANCH.trim() ?: 'develop'

                    if (!params.GO_REPO_URL.trim()) {
                        error('GO_REPO_URL is required.')
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
                        error('BRANCH contains unsupported characters.')
                    }
                    if (!(params.GO_BUILD_PACKAGE ==~ /[A-Za-z0-9._\/-]+/)) {
                        error('GO_BUILD_PACKAGE contains unsupported characters.')
                    }
                    if (!(params.GO_VERSION ==~ /[0-9]+\.[0-9]+([.][0-9]+)?/)) {
                        error('GO_VERSION must look like 1.25 or 1.25.1.')
                    }
                    if (!(params.IMAGE_REPOSITORY ==~ /[A-Za-z0-9._\/-]+/)) {
                        error('IMAGE_REPOSITORY contains unsupported characters.')
                    }
                    if (!(params.HOST_PORT ==~ /[0-9]+/) || !(params.CONTAINER_PORT ==~ /[0-9]+/)) {
                        error('HOST_PORT and CONTAINER_PORT must be numeric.')
                    }

                    def hostPort = params.HOST_PORT.toInteger()
                    def containerPort = params.CONTAINER_PORT.toInteger()
                    if (hostPort < 1 || hostPort > 65535 || containerPort < 1 || containerPort > 65535) {
                        error('HOST_PORT and CONTAINER_PORT must be between 1 and 65535.')
                    }

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
                        def remote = [url: params.GO_REPO_URL.trim()]
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

        stage('Test') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                sh '''
                    set -eu
                    docker run --rm \
                        -v "$SOURCE_DIR:/src" \
                        -w /src \
                        "golang:$GO_VERSION-bookworm" \
                        go test ./...
                '''
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
GO_SOURCE_DIR=${env.REMOTE_RELEASE_DIR}/sources/go-backend
GO_DOCKERFILE=${env.REMOTE_RELEASE_DIR}/docker/go.Dockerfile
GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}
GO_VERSION=${params.GO_VERSION}
GO_IMAGE_REPOSITORY=${params.IMAGE_REPOSITORY}
IMAGE_TAG=${env.IMAGE_TAG}
APP_ENV=${params.ENVIRONMENT}
HOST_PORT=${params.HOST_PORT}
CONTAINER_PORT=${params.CONTAINER_PORT}
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
                            "command -v rsync >/dev/null && docker version && docker compose version && mkdir -p '$REMOTE_RELEASE_DIR/sources/go-backend'"

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
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$SOURCE_DIR/" \
                            "$target:$REMOTE_RELEASE_DIR/sources/go-backend/"

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

def composeEnvironment() {
    return [
        "SERVICE=${params.SERVICE}",
        "ACTION=${params.ACTION}",
        "APP_ENV=${params.ENVIRONMENT}",
        "GO_SOURCE_DIR=${env.SOURCE_DIR}",
        "GO_DOCKERFILE=${env.GO_DOCKERFILE}",
        "GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}",
        "GO_VERSION=${params.GO_VERSION}",
        "GO_IMAGE_REPOSITORY=${params.IMAGE_REPOSITORY}",
        "IMAGE_TAG=${env.IMAGE_TAG}",
        "HOST_PORT=${params.HOST_PORT}",
        "CONTAINER_PORT=${params.CONTAINER_PORT}",
        "COMPOSE_PROJECT_NAME=deployment-${params.ENVIRONMENT}"
    ]
}
