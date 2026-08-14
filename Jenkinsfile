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
            choices: ['go-backend', 'react-frontend', 'ruby-service', 'all'],
            description: 'Application service to build or deploy. all processes Go, React and Ruby in one run.'
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
            name: 'RUBY_REPO_URL',
            defaultValue: '',
            description: 'HTTPS or SSH URL of the Ruby application repository.'
        )
        string(
            name: 'RUBY_REPO_BRANCH',
            defaultValue: 'develop',
            description: 'Branch in the Ruby application repository. Blank falls back to develop.'
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
            choices: ['unless-stopped', 'on-failure', 'no'],
            description: 'Restart behavior for the long-running Go backend container.'
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
            name: 'RUBY_VERSION',
            defaultValue: '3.4.5',
            description: 'Ruby builder/runtime image version compatible with the application.'
        )
        string(
            name: 'RUBY_TEST_FILE',
            defaultValue: 'test/app_test.rb',
            description: 'Ruby test entry file, relative to the application repository root.'
        )
        string(
            name: 'RUBY_IMAGE_REPOSITORY',
            defaultValue: 'local/ruby-service',
            description: 'Ruby Docker image repository/name, without the tag.'
        )
        string(
            name: 'RUBY_HOST_PORT',
            defaultValue: '9292',
            description: 'Host port used to access the Ruby application.'
        )
        string(
            name: 'RUBY_CONTAINER_PORT',
            defaultValue: '9292',
            description: 'Puma port inside the Ruby container.'
        )
        choice(
            name: 'RUBY_RESTART_POLICY',
            choices: ['unless-stopped', 'on-failure', 'no'],
            description: 'Restart behavior for the long-running Ruby service.'
        )
        string(
            name: 'RUBY_MEMORY_LIMIT',
            defaultValue: '256m',
            description: 'Maximum runtime memory for the Ruby/Puma container.'
        )
        string(
            name: 'RUBY_CPU_LIMIT',
            defaultValue: '0.50',
            description: 'Maximum CPU cores for the Ruby/Puma container.'
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
                    def selectedServices = selectedServiceNames(params.SERVICE)
                    env.SELECTED_SERVICES = selectedServices.join(' ')

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

                    def usedHostPorts = [:]
                    selectedServices.each { serviceName ->
                        def service = serviceConfiguration(serviceName)
                        def repoUrl = params[service.repoParameter].trim()
                        def branch = params[service.branchParameter].trim() ?: 'develop'

                        if (!repoUrl) {
                            error("${service.repoParameter} is required when SERVICE=${params.SERVICE}.")
                        }
                        if (!(branch ==~ /[A-Za-z0-9._\/-]+/)) {
                            error("${service.branchParameter} contains unsupported characters.")
                        }
                        if (!(params[service.imageParameter] ==~ /[A-Za-z0-9._\/-]+/)) {
                            error("${service.imageParameter} contains unsupported characters.")
                        }

                        validatePort(params[service.hostPortParameter], service.hostPortParameter)
                        validatePort(params[service.containerPortParameter], service.containerPortParameter)
                        def hostPort = params[service.hostPortParameter]
                        if (usedHostPorts.containsKey(hostPort)) {
                            error("Host port ${hostPort} is assigned to both ${usedHostPorts[hostPort]} and ${serviceName}.")
                        }
                        usedHostPorts[hostPort] = serviceName

                        if (!(params[service.memoryParameter] ==~ /[1-9][0-9]*[kKmMgG]/)) {
                            error("${service.memoryParameter} must be a positive Docker memory value such as 256m or 1g.")
                        }
                        def cpuValue = params[service.cpuParameter]
                        def isNumeric = cpuValue ==~ /[0-9]+(\.[0-9]+)?/
                        def isZero = cpuValue ==~ /0+(\.0+)?/
                        if (!isNumeric || isZero) {
                            error("${service.cpuParameter} must be a positive CPU number such as 0.50 or 1.")
                        }
                    }

                    if (selectedServices.contains('go-backend')) {
                        if (!(params.GO_BUILD_PACKAGE ==~ /[A-Za-z0-9._\/-]+/)) {
                            error('GO_BUILD_PACKAGE contains unsupported characters.')
                        }
                        validateVersion(params.GO_VERSION, 'GO_VERSION')
                    }
                    if (selectedServices.contains('react-frontend')) {
                        validateVersion(params.NODE_VERSION, 'NODE_VERSION')
                        validatePositiveInteger(params.NODE_BUILD_MEMORY_MB, 'NODE_BUILD_MEMORY_MB', 8192)
                        if (params.REACT_CONTAINER_PORT != '80') {
                            error('REACT_CONTAINER_PORT must be 80 because the production Nginx image listens on port 80.')
                        }
                    }
                    if (selectedServices.contains('ruby-service')) {
                        if (!(params.RUBY_TEST_FILE ==~ /[A-Za-z0-9._\/-]+/)) {
                            error('RUBY_TEST_FILE contains unsupported characters.')
                        }
                        validateVersion(params.RUBY_VERSION, 'RUBY_VERSION')
                        if (params.RUBY_CONTAINER_PORT != '9292') {
                            error('RUBY_CONTAINER_PORT must be 9292 because the production Puma image and health check use port 9292.')
                        }
                    }
                    if (!(params.DOCKER_LOG_MAX_SIZE ==~ /[1-9][0-9]*[kKmMgG]/)) {
                        error('DOCKER_LOG_MAX_SIZE must be a positive size such as 10m.')
                    }
                    validatePositiveInteger(params.DOCKER_LOG_MAX_FILES, 'DOCKER_LOG_MAX_FILES', 10)
                    validatePositiveInteger(params.RELEASE_RETENTION, 'RELEASE_RETENTION', 100)
                    validatePositiveInteger(params.IMAGE_RETENTION_HOURS, 'IMAGE_RETENTION_HOURS', 8760)
                    validatePositiveInteger(params.BUILD_CACHE_RETENTION_HOURS, 'BUILD_CACHE_RETENTION_HOURS', 8760)

                    env.REMOTE_RELEASE_DIR = "${params.LOCAL_SERVER_BASE_DIR}/projects/${params.PROJECT_ID}/releases/${env.BUILD_NUMBER}"
                    echo "Selected services: ${env.SELECTED_SERVICES}"
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

        stage('Checkout applications') {
            steps {
                script {
                    dir("${env.WORKSPACE}/sources") {
                        deleteDir()
                    }

                    def checkoutBranches = [:]
                    selectedServiceNames(params.SERVICE).each { selectedName ->
                        def serviceName = selectedName
                        def service = serviceConfiguration(serviceName)
                        checkoutBranches["Checkout ${serviceName}"] = {
                            checkoutApplication(serviceName, service)
                        }
                    }
                    parallel checkoutBranches

                    selectedServiceNames(params.SERVICE).each { serviceName ->
                        def commit = readFile(file: ".commit-${serviceName}").trim()
                        setServiceImageTag(serviceName, "${env.BUILD_NUMBER}-${commit}")
                    }
                }
            }
        }

        stage('Test applications') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    def testBranches = [:]
                    selectedServiceNames(params.SERVICE).each { selectedName ->
                        def serviceName = selectedName
                        testBranches["Test ${serviceName}"] = {
                            testApplication(serviceName)
                        }
                    }
                    parallel testBranches
                }
            }
        }

        stage('Validate Compose') {
            steps {
                script {
                    withEnv(composeEnvironment()) {
                        def profileArguments = selectedServiceNames(params.SERVICE)
                            .collect { serviceConfiguration(it).profile }
                            .collect { "--profile ${it}" }
                            .join(' ')
                        sh "docker compose --file '${env.COMPOSE_FILE}' ${profileArguments} config --quiet"
                    }
                }
            }
        }

        stage('Prepare remote configuration') {
            steps {
                script {
                    writeFile file: '.env.remote', text: """\
SERVICE=${params.SERVICE}
SELECTED_SERVICES=${env.SELECTED_SERVICES}
GO_SOURCE_DIR=${env.REMOTE_RELEASE_DIR}/sources/go-backend
GO_DOCKERFILE=${env.REMOTE_RELEASE_DIR}/docker/go.Dockerfile
GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}
GO_VERSION=${params.GO_VERSION}
GO_IMAGE_REPOSITORY=${params.GO_IMAGE_REPOSITORY}
GO_IMAGE_TAG=${env.GO_IMAGE_TAG ?: 'not-selected'}
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
REACT_IMAGE_TAG=${env.REACT_IMAGE_TAG ?: 'not-selected'}
REACT_HOST_PORT=${params.REACT_HOST_PORT}
REACT_CONTAINER_PORT=${params.REACT_CONTAINER_PORT}
REACT_RESTART_POLICY=${params.REACT_RESTART_POLICY}
REACT_MEMORY_LIMIT=${params.REACT_MEMORY_LIMIT}
REACT_CPU_LIMIT=${params.REACT_CPU_LIMIT}
RUBY_SOURCE_DIR=${env.REMOTE_RELEASE_DIR}/sources/ruby-service
RUBY_DOCKERFILE=${env.REMOTE_RELEASE_DIR}/docker/ruby.Dockerfile
RUBY_VERSION=${params.RUBY_VERSION}
RUBY_IMAGE_REPOSITORY=${params.RUBY_IMAGE_REPOSITORY}
RUBY_IMAGE_TAG=${env.RUBY_IMAGE_TAG ?: 'not-selected'}
RUBY_HOST_PORT=${params.RUBY_HOST_PORT}
RUBY_CONTAINER_PORT=${params.RUBY_CONTAINER_PORT}
RUBY_RESTART_POLICY=${params.RUBY_RESTART_POLICY}
RUBY_MEMORY_LIMIT=${params.RUBY_MEMORY_LIMIT}
RUBY_CPU_LIMIT=${params.RUBY_CPU_LIMIT}
DOCKER_LOG_MAX_SIZE=${params.DOCKER_LOG_MAX_SIZE}
DOCKER_LOG_MAX_FILES=${params.DOCKER_LOG_MAX_FILES}
RELEASE_RETENTION=${params.RELEASE_RETENTION}
IMAGE_RETENTION_HOURS=${params.IMAGE_RETENTION_HOURS}
PRUNE_BUILD_CACHE=${params.PRUNE_BUILD_CACHE}
BUILD_CACHE_RETENTION_HOURS=${params.BUILD_CACHE_RETENTION_HOURS}
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
                            "command -v rsync >/dev/null && docker version && docker compose version && mkdir -p '$REMOTE_RELEASE_DIR/sources'"

                        rsync -az \
                            --exclude='.git/' \
                            --exclude='.env' \
                            --exclude='.env.remote' \
                            --exclude='.commit-*' \
                            --exclude='sources/' \
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$WORKSPACE/" \
                            "$target:$REMOTE_RELEASE_DIR/"

                        rsync -az \
                            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                            "$WORKSPACE/.env.remote" \
                            "$target:$REMOTE_RELEASE_DIR/.env"
                        '''

                        script {
                            def syncBranches = [:]
                            selectedServiceNames(params.SERVICE).each { selectedName ->
                                def serviceName = selectedName
                                def service = serviceConfiguration(serviceName)
                                syncBranches["Sync ${serviceName}"] = {
                                    withEnv([
                                        "SOURCE_DIR=${env.WORKSPACE}/sources/${service.sourceSubdir}",
                                        "SOURCE_SUBDIR=${service.sourceSubdir}"
                                    ]) {
                                        sh '''
                                            set -eu
                                            target="$LOCAL_SERVER_USER@$LOCAL_SERVER_HOST"

                                            ssh \
                                                -o BatchMode=yes \
                                                -o StrictHostKeyChecking=yes \
                                                -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
                                                "$target" \
                                                "mkdir -p '$REMOTE_RELEASE_DIR/sources/$SOURCE_SUBDIR'"

                                            rsync -az \
                                                --exclude='.git/' \
                                                --exclude='node_modules/' \
                                                --exclude='dist/' \
                                                -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
                                                "$SOURCE_DIR/" \
                                                "$target:$REMOTE_RELEASE_DIR/sources/$SOURCE_SUBDIR/"
                                        '''
                                    }
                                }
                            }
                            parallel syncBranches
                        }
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
            hostPortParameter: 'GO_HOST_PORT',
            containerPortParameter: 'GO_CONTAINER_PORT',
            memoryParameter: 'GO_MEMORY_LIMIT',
            cpuParameter: 'GO_CPU_LIMIT',
            sourceSubdir: 'go-backend',
            profile: 'go'
        ],
        'react-frontend': [
            repoParameter: 'REACT_REPO_URL',
            branchParameter: 'REACT_REPO_BRANCH',
            imageParameter: 'REACT_IMAGE_REPOSITORY',
            hostPortParameter: 'REACT_HOST_PORT',
            containerPortParameter: 'REACT_CONTAINER_PORT',
            memoryParameter: 'REACT_MEMORY_LIMIT',
            cpuParameter: 'REACT_CPU_LIMIT',
            sourceSubdir: 'react-frontend',
            profile: 'react'
        ],
        'ruby-service': [
            repoParameter: 'RUBY_REPO_URL',
            branchParameter: 'RUBY_REPO_BRANCH',
            imageParameter: 'RUBY_IMAGE_REPOSITORY',
            hostPortParameter: 'RUBY_HOST_PORT',
            containerPortParameter: 'RUBY_CONTAINER_PORT',
            memoryParameter: 'RUBY_MEMORY_LIMIT',
            cpuParameter: 'RUBY_CPU_LIMIT',
            sourceSubdir: 'ruby-service',
            profile: 'ruby'
        ]
    ]

    if (!services.containsKey(serviceName)) {
        error("Unsupported SERVICE: ${serviceName}")
    }
    return services[serviceName]
}

def selectedServiceNames(String selection) {
    if (selection == 'all') {
        return ['go-backend', 'react-frontend', 'ruby-service']
    }
    serviceConfiguration(selection)
    return [selection]
}

def checkoutApplication(String serviceName, Map service) {
    def repoUrl = params[service.repoParameter].trim()
    def branch = params[service.branchParameter].trim() ?: 'develop'
    def remote = [url: repoUrl]
    if (params.GIT_CREDENTIALS_ID.trim()) {
        remote.credentialsId = params.GIT_CREDENTIALS_ID.trim()
    }

    dir("${env.WORKSPACE}/sources/${service.sourceSubdir}") {
        deleteDir()
        checkout([
            $class: 'GitSCM',
            branches: [[name: "*/${branch}"]],
            userRemoteConfigs: [remote]
        ])
        def commit = sh(
            script: 'git rev-parse --short=12 HEAD',
            returnStdout: true
        ).trim()
        dir("${env.WORKSPACE}") {
            writeFile file: ".commit-${serviceName}", text: "${commit}\n"
        }
    }
}

def testApplication(String serviceName) {
    def service = serviceConfiguration(serviceName)
    withEnv(["SOURCE_DIR=${env.WORKSPACE}/sources/${service.sourceSubdir}"]) {
        if (serviceName == 'go-backend') {
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
        } else if (serviceName == 'react-frontend') {
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
        } else if (serviceName == 'ruby-service') {
            sh '''
                set -eu
                docker run --rm \
                    --memory=1g \
                    --cpus=1.0 \
                    --pids-limit=256 \
                    -v "$SOURCE_DIR:/app:ro" \
                    -w /app \
                    "ruby:$RUBY_VERSION-slim" \
                    ruby -Itest "$RUBY_TEST_FILE"
            '''
        }
    }
}

def setServiceImageTag(String serviceName, String imageTag) {
    if (serviceName == 'go-backend') {
        env.GO_IMAGE_TAG = imageTag
    } else if (serviceName == 'react-frontend') {
        env.REACT_IMAGE_TAG = imageTag
    } else if (serviceName == 'ruby-service') {
        env.RUBY_IMAGE_TAG = imageTag
    } else {
        error("Unsupported SERVICE: ${serviceName}")
    }
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
        "SELECTED_SERVICES=${env.SELECTED_SERVICES}",
        "APP_ENV=${params.ENVIRONMENT}",
        "GO_SOURCE_DIR=${env.WORKSPACE}/sources/go-backend",
        "GO_DOCKERFILE=${env.WORKSPACE}/docker/go.Dockerfile",
        "GO_BUILD_PACKAGE=${params.GO_BUILD_PACKAGE}",
        "GO_VERSION=${params.GO_VERSION}",
        "GO_IMAGE_REPOSITORY=${params.GO_IMAGE_REPOSITORY}",
        "GO_IMAGE_TAG=${env.GO_IMAGE_TAG ?: 'not-selected'}",
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
        "REACT_IMAGE_TAG=${env.REACT_IMAGE_TAG ?: 'not-selected'}",
        "REACT_HOST_PORT=${params.REACT_HOST_PORT}",
        "REACT_CONTAINER_PORT=${params.REACT_CONTAINER_PORT}",
        "REACT_RESTART_POLICY=${params.REACT_RESTART_POLICY}",
        "REACT_MEMORY_LIMIT=${params.REACT_MEMORY_LIMIT}",
        "REACT_CPU_LIMIT=${params.REACT_CPU_LIMIT}",
        "RUBY_SOURCE_DIR=${env.WORKSPACE}/sources/ruby-service",
        "RUBY_DOCKERFILE=${env.WORKSPACE}/docker/ruby.Dockerfile",
        "RUBY_VERSION=${params.RUBY_VERSION}",
        "RUBY_IMAGE_REPOSITORY=${params.RUBY_IMAGE_REPOSITORY}",
        "RUBY_IMAGE_TAG=${env.RUBY_IMAGE_TAG ?: 'not-selected'}",
        "RUBY_HOST_PORT=${params.RUBY_HOST_PORT}",
        "RUBY_CONTAINER_PORT=${params.RUBY_CONTAINER_PORT}",
        "RUBY_RESTART_POLICY=${params.RUBY_RESTART_POLICY}",
        "RUBY_MEMORY_LIMIT=${params.RUBY_MEMORY_LIMIT}",
        "RUBY_CPU_LIMIT=${params.RUBY_CPU_LIMIT}",
        "DOCKER_LOG_MAX_SIZE=${params.DOCKER_LOG_MAX_SIZE}",
        "DOCKER_LOG_MAX_FILES=${params.DOCKER_LOG_MAX_FILES}",
        "COMPOSE_PROJECT_NAME=${params.PROJECT_ID}-${params.ENVIRONMENT}"
    ]
}
