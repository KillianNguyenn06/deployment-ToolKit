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
                }

                sh '''
                    set -eu
                    docker version
                    docker compose version
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

        stage('Build image') {
            when {
                expression { params.ACTION == 'build' }
            }
            steps {
                withEnv(composeEnvironment()) {
                    sh '''
                        set -eu
                        docker compose --file "$COMPOSE_FILE" build "$SERVICE"
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                withEnv(composeEnvironment()) {
                    sh '''
                        set -eu
                        docker compose --file "$COMPOSE_FILE" up --build -d "$SERVICE"
                    '''
                }
            }
        }

        stage('Verify and measure') {
            steps {
                withEnv(composeEnvironment()) {
                    sh '''
                        set -eu
                        docker image inspect "$GO_IMAGE_REPOSITORY:$IMAGE_TAG" \
                            --format 'Image={{.RepoTags}} SizeBytes={{.Size}}'
                        docker image ls "$GO_IMAGE_REPOSITORY:$IMAGE_TAG"

                        if [ "$ACTION" = "deploy" ]; then
                            docker compose --file "$COMPOSE_FILE" ps "$SERVICE"
                            container_id="$(docker compose --file "$COMPOSE_FILE" ps -q "$SERVICE")"
                            test -n "$container_id"
                            test "$(docker inspect --format '{{.State.Running}}' "$container_id")" = "true"
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'compose.yaml,docker/**', allowEmptyArchive: true
        }
        failure {
            script {
                if (fileExists('compose.yaml')) {
                    withEnv(composeEnvironment()) {
                        sh 'docker compose --file "$COMPOSE_FILE" ps || true'
                    }
                }
            }
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
