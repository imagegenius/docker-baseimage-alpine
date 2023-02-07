pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '60'))
    parallelsAlwaysFailFast()
  }
  // Input to determine if this is a package check
  parameters {
     string(defaultValue: 'false', description: 'Run Package Check', name: 'PACKAGE_CHECK')
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('github_token')
    BUILD_VERSION_ARG = 'OS'
    IG_USER = 'imagegenius'
    IG_REPO = 'docker-baseimage-alpine'
    CONTAINER_NAME = 'baseimage-alpine'
    DIST_IMAGE = 'alpine'
    MULTIARCH = 'true'
    CI = 'true'
    CI_WEB = 'false'
    CI_PORT = '80'
    CI_SSL = 'true'
    CI_DELAY = '15'
    CI_DOCKERENV = ''
    CI_AUTH = ''
    CI_WEBPATH = ''
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.IG_RELEASE = sh(
            script: '''docker run --rm ghcr.io/linuxserver/alexeiled-skopeo sh -c 'skopeo inspect docker://ghcr.io/'${IG_USER}'/'${CONTAINER_NAME}':3.17 2>/dev/null' | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-ig' || : ''',
            returnStdout: true).trim()
          env.IG_RELEASE_NOTES = sh(
            script: '''cat readme-vars.yml | awk -F \\" '/date: "[0-9][0-9].[0-9][0-9].[0-9][0-9]:/ {print $4;exit;}' | sed -E ':a;N;$!ba;s/\\r{0,1}\\n/\\\\n/g' ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.IG_USER + '/' + env.IG_REPO + '/commit/' + env.GIT_COMMIT
          env.PULL_REQUEST = env.CHANGE_ID
          env.TEMPLATED_FILES = 'Jenkinsfile README.md LICENSE .editorconfig  ./.github/workflows/external_trigger_scheduler.yml  ./.github/workflows/package_trigger_scheduler.yml  ./.github/workflows/external_trigger.yml ./.github/workflows/package_trigger.yml'
        }
        script{
          env.IG_RELEASE_NUMBER = sh(
            script: '''echo ${IG_RELEASE} |sed 's/^.*-ig//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.IG_TAG_NUMBER = sh(
            script: '''#!/bin/bash
                       tagsha=$(git rev-list -n 1 ${IG_RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${IG_RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${IG_RELEASE_NUMBER}
                       else
                         echo $((${IG_RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* #######################
       Package Version Tagging
       ####################### */
    // Grab the current package versions in Git to determine package tag
    stage("Set Package tag"){
      steps{
        script{
          env.PACKAGE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e package_versions.txt ] ; then
                         cat package_versions.txt | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is an os release set release type to none to indicate no external release
    stage("Set ENV os"){
      steps{
        script{
          env.EXT_RELEASE = env.PACKAGE_TAG
          env.RELEASE_LINK = 'none'
        }
      }
    }
    // Sanitize the release tag and strip illegal docker or github characters
    stage("Sanitize tag"){
      steps{
        script{
          env.EXT_RELEASE_CLEAN = sh(
            script: '''echo ${EXT_RELEASE} | sed 's/[~,%@+;:/]//g' ''',
            returnStdout: true).trim()

          def semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)\.(\d+)/
          if (semver.find()) {
            env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
          } else {
            semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)(?:\.(\d+))?(.*)/
            if (semver.find()) {
              if (semver[0][3]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
              } else if (!semver[0][3] && !semver[0][4]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${(new Date()).format('YYYYMMdd')}"
              }
            }
          }

          if (env.SEMVER != null) {
            if (BRANCH_NAME != "master" && BRANCH_NAME != "main") {
              env.SEMVER = "${env.SEMVER}-${BRANCH_NAME}"
            }
            println("SEMVER: ${env.SEMVER}")
          } else {
            println("No SEMVER detected")
          }

        }
      }
    }
    // If this is a 3.17 build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.GITHUBIMAGE = 'ghcr.io/' + env.IG_USER + '/' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-3.17-' + env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER + '|arm64v8-3.17-' + env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER
          } else {
            env.CI_TAGS = '3.17-' + env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER
          env.META_TAG = '3.17-' + env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER
          env.EXT_RELEASE_TAG = '3.17-version-' + env.EXT_RELEASE_CLEAN
        }
      }
    }
    // If this is a dev build use dev docker endpoints
    stage("Set ENV dev build"){
      when {
        not {branch "3.17"}
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.GITHUBIMAGE = 'ghcr.io/' + env.IG_USER + '/igdev-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm64v8-3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          } else {
            env.CI_TAGS = '3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.META_TAG = '3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.EXT_RELEASE_TAG = '3.17-version-' + env.EXT_RELEASE_CLEAN
        }
      }
    }
    // If this is a pull request build use dev docker endpoints
    stage("Set ENV PR build"){
      when {
        not {environment name: 'CHANGE_ID', value: ''}
      }
      steps {
        script{
          env.GITHUBIMAGE = 'ghcr.io/' + env.IG_USER + '/igpipepr-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST + '|arm64v8-3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          } else {
            env.CI_TAGS = '3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          env.META_TAG = '3.17-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          env.EXT_RELEASE_TAG = '3.17-version-' + env.EXT_RELEASE_CLEAN
          env.CODE_URL = 'https://github.com/' + env.IG_USER + '/' + env.IG_REPO + '/pull/' + env.PULL_REQUEST
        }
      }
    }
    // Use helper containers to render templated files
    stage('Update-Templates') {
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        sh '''#!/bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              docker pull ghcr.io/imagegenius/jenkins-builder:latest
              docker run --rm -e CONTAINER_NAME=${CONTAINER_NAME} -e GITHUB_BRANCH=3.17 -v ${TEMPDIR}:/ansible/jenkins ghcr.io/imagegenius/jenkins-builder:latest 
              # Stage 1 - Jenkinsfile update
              if [[ "$(md5sum Jenkinsfile | awk '{ print $1 }')" != "$(md5sum ${TEMPDIR}/docker-${CONTAINER_NAME}/Jenkinsfile | awk '{ print $1 }')" ]]; then
                mkdir -p ${TEMPDIR}/repo
                git clone https://github.com/${IG_USER}/${IG_REPO}.git ${TEMPDIR}/repo/${IG_REPO}
                cd ${TEMPDIR}/repo/${IG_REPO}
                git checkout -f 3.17
                cp ${TEMPDIR}/docker-${CONTAINER_NAME}/Jenkinsfile ${TEMPDIR}/repo/${IG_REPO}/
                git add Jenkinsfile
                git commit -m 'Bot Updating Templated Files'
                git push https://ImageGeniusCI:${GITHUB_TOKEN}@github.com/${IG_USER}/${IG_REPO}.git --all
                echo "true" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Updating Jenkinsfile"
                rm -rf ${TEMPDIR}
                exit 0
              else
                echo "Jenkinsfile is up to date."
              fi
              # Stage 2 - Update templates
              CURRENTHASH=$(grep -hs ^ ${TEMPLATED_FILES} | md5sum | cut -c1-8)
              cd ${TEMPDIR}/docker-${CONTAINER_NAME}
              NEWHASH=$(grep -hs ^ ${TEMPLATED_FILES} | md5sum | cut -c1-8)
              if [[ "${CURRENTHASH}" != "${NEWHASH}" ]] || ! grep -q '.jenkins-external' "${WORKSPACE}/.gitignore" 2>/dev/null; then
                mkdir -p ${TEMPDIR}/repo
                git clone https://github.com/${IG_USER}/${IG_REPO}.git ${TEMPDIR}/repo/${IG_REPO}
                cd ${TEMPDIR}/repo/${IG_REPO}
                git checkout -f 3.17
                cd ${TEMPDIR}/docker-${CONTAINER_NAME}
                mkdir -p ${TEMPDIR}/repo/${IG_REPO}/.github/workflows
                mkdir -p ${TEMPDIR}/repo/${IG_REPO}/.github/ISSUE_TEMPLATE
                cp --parents ${TEMPLATED_FILES} ${TEMPDIR}/repo/${IG_REPO}/ || :
                cd ${TEMPDIR}/repo/${IG_REPO}/
                if ! grep -q '.jenkins-external' .gitignore 2>/dev/null; then
                  echo ".jenkins-external" >> .gitignore
                  git add .gitignore
                fi
                git add ${TEMPLATED_FILES}
                git commit -m 'Bot Updating Templated Files'
                git push https://ImageGeniusCI:${GITHUB_TOKEN}@github.com/${IG_USER}/${IG_REPO}.git --all
                echo "true" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              else
                echo "false" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              fi
              rm -rf ${TEMPDIR}'''
        script{
          env.FILES_UPDATED = sh(
            script: '''cat /tmp/${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the Templated files were just updated
    stage('Template-exit') {
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'FILES_UPDATED', value: 'true'
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to IG Repo
    stage('Build-Single') {
      when {
        expression {
          env.MULTIARCH == 'false' || params.PACKAGE_CHECK == 'true'
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Running on node: ${NODE_NAME}"
        sh "docker build \
          --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
          --label \"org.opencontainers.image.authors=imagegenius.io\" \
          --label \"org.opencontainers.image.url=https://github.com/imagegenius/docker-baseimage-alpine/packages\" \
          --label \"org.opencontainers.image.source=https://github.com/imagegenius/docker-baseimage-alpine\" \
          --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ig${IG_TAG_NUMBER}\" \
          --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.vendor=imagegenius.io\" \
          --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
          --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.title=Baseimage-alpine\" \
          --label \"org.opencontainers.image.description=baseimage-alpine image by imagegenius.io\" \
          --no-cache --pull -t ${GITHUBIMAGE}:${META_TAG} \
          --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
      }
    }
    // Build MultiArch Docker containers for push to IG Repo
    stage('Build-Multi') {
      when {
        allOf {
          environment name: 'MULTIARCH', value: 'true'
          expression { params.PACKAGE_CHECK == 'false' }
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            echo "Running on node: ${NODE_NAME}"
            sh "docker build \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=imagegenius.io\" \
              --label \"org.opencontainers.image.url=https://github.com/imagegenius/docker-baseimage-alpine/packages\" \
              --label \"org.opencontainers.image.source=https://github.com/imagegenius/docker-baseimage-alpine\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ig${IG_TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=imagegenius.io\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=Baseimage-alpine\" \
              --label \"org.opencontainers.image.description=baseimage-alpine image by imagegenius.io\" \
              --no-cache --pull -t ${GITHUBIMAGE}:amd64-${META_TAG} \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
          }
        }
        stage('Build ARM64') {
          agent {
            label 'ARM64'
          }
          steps {
            echo "Running on node: ${NODE_NAME}"
            echo 'Logging into Github'
            sh '''#!/bin/bash
                  echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGeniusCI --password-stdin
               '''
            sh "docker build \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=imagegenius.io\" \
              --label \"org.opencontainers.image.url=https://github.com/imagegenius/docker-baseimage-alpine/packages\" \
              --label \"org.opencontainers.image.source=https://github.com/imagegenius/docker-baseimage-alpine\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ig${IG_TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=imagegenius.io\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=Baseimage-alpine\" \
              --label \"org.opencontainers.image.description=baseimage-alpine image by imagegenius.io\" \
              --no-cache --pull -f Dockerfile.aarch64 -t ${GITHUBIMAGE}:arm64v8-${META_TAG} \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
            sh '''docker tag ${GITHUBIMAGE}:arm64v8-${META_TAG} ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker push ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker rmi \
				    ${GITHUBIMAGE}:arm64v8-${META_TAG} \
                    ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :
               '''
          }
        }
      }
    }
    // Take the image we just built and dump package versions for comparison
    stage('Update-packages') {
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#!/bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              if [ "${MULTIARCH}" == "true" ] && [ "${PACKAGE_CHECK}" == "false" ]; then
                LOCAL_CONTAINER=${GITHUBIMAGE}:amd64-${META_TAG}
              else
                LOCAL_CONTAINER=${GITHUBIMAGE}:${META_TAG}
              fi
              if [ "${DIST_IMAGE}" == "alpine" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apk info -v > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "ubuntu" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apt list -qq --installed | sed "s#/.*now ##g" | cut -d" " -f1 > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "fedora" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  rpm -qa > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "arch" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  pacman -Q > /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              fi
              NEW_PACKAGE_TAG=$(md5sum ${TEMPDIR}/package_versions.txt | cut -c1-8 )
              echo "Package tag sha from current packages in buit container is ${NEW_PACKAGE_TAG} comparing to old ${PACKAGE_TAG} from github"
              if [ "${NEW_PACKAGE_TAG}" != "${PACKAGE_TAG}" ]; then
                git clone https://github.com/${IG_USER}/${IG_REPO}.git ${TEMPDIR}/${IG_REPO}
                git --git-dir ${TEMPDIR}/${IG_REPO}/.git checkout -f 3.17
                cp ${TEMPDIR}/package_versions.txt ${TEMPDIR}/${IG_REPO}/
                cd ${TEMPDIR}/${IG_REPO}/
                wait
                git add package_versions.txt
                git commit -m 'Bot Updating Package Versions'
                git push https://ImageGeniusCI:${GITHUB_TOKEN}@github.com/${IG_USER}/${IG_REPO}.git --all
                echo "true" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag updated, stopping build process"
              else
                echo "false" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag is same as previous continue with build process"
              fi
              rm -rf ${TEMPDIR}
           '''
        script{
          env.PACKAGE_UPDATED = sh(
            script: '''cat /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the package file was just updated
    stage('PACKAGE-exit') {
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    // Exit the build if this is just a package check and there are no changes to push
    stage('PACKAGECHECK-exit') {
      when {
        branch "3.17"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
        expression {
          params.PACKAGE_CHECK == 'true'
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* #######
       Testing
       ####### */
    // Run Container tests
    stage('Test') {
      when {
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          string(credentialsId: 'ci-tests-s3-key-id', variable: 'S3_KEY'),
          string(credentialsId: 'ci-tests-s3-secret-access-key', variable: 'S3_SECRET')
        ]) {
          script{
            env.CI_URL = 'https://ci-tests.imagegenius.io/' + env.CONTAINER_NAME + '/' + env.META_TAG + '/index.html'
          }
          sh '''#!/bin/bash
                set -e
                docker pull ghcr.io/imagegenius/ci:latest
                if [ "${MULTIARCH}" == "true" ]; then
                  docker pull ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker tag ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${GITHUBIMAGE}:arm64v8-${META_TAG}
                fi
                docker run --rm \
                --shm-size=1gb \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -e IMAGE=\"${GITHUBIMAGE}\" \
				-e CONTAINER=\"${CONTAINER_NAME}\" \
                -e DELAY_START=\"${CI_DELAY}\" \
                -e TAGS=\"${CI_TAGS}\" \
                -e META_TAG=\"${META_TAG}\" \
                -e PORT=\"${CI_PORT}\" \
                -e SSL=\"${CI_SSL}\" \
                -e BASE=\"${DIST_IMAGE}\" \
                -e BRANCH=\"3.17\" \
                -e SECRET_KEY=\"${S3_SECRET}\" \
                -e ACCESS_KEY=\"${S3_KEY}\" \
                -e DOCKER_ENV=\"${CI_DOCKERENV}\" \
                -e WEB_SCREENSHOT=\"${CI_WEB}\" \
                -e WEB_AUTH=\"${CI_AUTH}\" \
                -e WEB_PATH=\"${CI_WEBPATH}\" \
                -t ghcr.io/imagegenius/ci:latest \
                python3 test_build.py
             '''
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#!/bin/bash
              set -e
              echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGeniusCI --password-stdin
              docker tag ${GITHUBIMAGE}:${META_TAG} ${GITHUBIMAGE}:3.17
              docker tag ${GITHUBIMAGE}:${META_TAG} ${GITHUBIMAGE}:${EXT_RELEASE_TAG}
              if [ -n "${SEMVER}" ]; then
                docker tag ${GITHUBIMAGE}:${META_TAG} ${GITHUBIMAGE}:${SEMVER}
              fi
              docker push ${GITHUBIMAGE}:3.17
              docker push ${GITHUBIMAGE}:${META_TAG}
              docker push ${GITHUBIMAGE}:${EXT_RELEASE_TAG}
              if [ -n "${SEMVER}" ]; then
                docker push ${GITHUBIMAGE}:${SEMVER}
              fi
           '''
        sh '''#!/bin/bash
              docker rmi \
                ${GITHUBIMAGE}:${META_TAG} \
                ${GITHUBIMAGE}:${EXT_RELEASE_TAG} \
                ${GITHUBIMAGE}:3.17 || :
              if [ -n "${SEMVER}" ]; then
                docker rmi ${GITHUBIMAGE}:${SEMVER} || :
              fi
           '''
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#!/bin/bash
              set -e
              echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGeniusCI --password-stdin
              docker tag ${GITHUBIMAGE}:amd64-${META_TAG} ${GITHUBIMAGE}:amd64-${META_TAG}
              docker tag ${GITHUBIMAGE}:arm64v8-${META_TAG} ${GITHUBIMAGE}:arm64v8-${META_TAG}
              docker tag ${GITHUBIMAGE}:amd64-${META_TAG} ${GITHUBIMAGE}:amd64-3.17
              docker tag ${GITHUBIMAGE}:arm64v8-${META_TAG} ${GITHUBIMAGE}:arm64v8-3.17
              docker tag ${GITHUBIMAGE}:amd64-${META_TAG} ${GITHUBIMAGE}:amd64-${EXT_RELEASE_TAG}
              docker tag ${GITHUBIMAGE}:arm64v8-${META_TAG} ${GITHUBIMAGE}:arm64v8-${EXT_RELEASE_TAG}
              if [ -n "${SEMVER}" ]; then
                docker tag ${GITHUBIMAGE}:amd64-${META_TAG} ${GITHUBIMAGE}:amd64-${SEMVER}
                docker tag ${GITHUBIMAGE}:arm64v8-${META_TAG} ${GITHUBIMAGE}:arm64v8-${SEMVER}
              fi
              docker push ${GITHUBIMAGE}:amd64-${META_TAG}
              docker push ${GITHUBIMAGE}:arm64v8-${META_TAG}
              docker push ${GITHUBIMAGE}:amd64-3.17
              docker push ${GITHUBIMAGE}:arm64v8-3.17
              docker push ${GITHUBIMAGE}:amd64-${EXT_RELEASE_TAG}
              docker push ${GITHUBIMAGE}:arm64v8-${EXT_RELEASE_TAG}
              if [ -n "${SEMVER}" ]; then
                docker push ${GITHUBIMAGE}:amd64-${SEMVER}
                docker push ${GITHUBIMAGE}:arm64v8-${SEMVER}
              fi
              docker manifest push --purge ${GITHUBIMAGE}:3.17 || :
              docker manifest create ${GITHUBIMAGE}:3.17 ${GITHUBIMAGE}:amd64-3.17 ${GITHUBIMAGE}:arm64v8-3.17
              docker manifest annotate ${GITHUBIMAGE}:3.17 ${GITHUBIMAGE}:arm64v8-3.17 --os linux --arch arm64 --variant v8
              docker manifest push --purge ${GITHUBIMAGE}:${META_TAG} || :
              docker manifest create ${GITHUBIMAGE}:${META_TAG} ${GITHUBIMAGE}:amd64-${META_TAG} ${GITHUBIMAGE}:arm64v8-${META_TAG}
              docker manifest annotate ${GITHUBIMAGE}:${META_TAG} ${GITHUBIMAGE}:arm64v8-${META_TAG} --os linux --arch arm64 --variant v8
              docker manifest push --purge ${GITHUBIMAGE}:${EXT_RELEASE_TAG} || :
              docker manifest create ${GITHUBIMAGE}:${EXT_RELEASE_TAG} ${GITHUBIMAGE}:amd64-${EXT_RELEASE_TAG} ${GITHUBIMAGE}:arm64v8-${EXT_RELEASE_TAG}
              docker manifest annotate ${GITHUBIMAGE}:${EXT_RELEASE_TAG} ${GITHUBIMAGE}:arm64v8-${EXT_RELEASE_TAG} --os linux --arch arm64 --variant v8
              if [ -n "${SEMVER}" ]; then
                docker manifest push --purge ${GITHUBIMAGE}:${SEMVER} || :
                docker manifest create ${GITHUBIMAGE}:${SEMVER} ${GITHUBIMAGE}:amd64-${SEMVER} ${GITHUBIMAGE}:arm64v8-${SEMVER}
                docker manifest annotate ${GITHUBIMAGE}:${SEMVER} ${GITHUBIMAGE}:arm64v8-${SEMVER} --os linux --arch arm64 --variant v8
              fi
              docker manifest push --purge ${GITHUBIMAGE}:3.17
              docker manifest push --purge ${GITHUBIMAGE}:${META_TAG} 
              docker manifest push --purge ${GITHUBIMAGE}:${EXT_RELEASE_TAG} 
              if [ -n "${SEMVER}" ]; then
                docker manifest push --purge ${GITHUBIMAGE}:${SEMVER} 
              fi
           '''
        sh '''#!/bin/bash
              docker rmi \
                ${GITHUBIMAGE}:arm64v8-${META_TAG} \
                ${GITHUBIMAGE}:arm64v8-3.17 \
                ${GITHUBIMAGE}:arm64v8-${EXT_RELEASE_TAG} || :
              if [ -n "${SEMVER}" ]; then
                docker rmi \
                ${GITHUBIMAGE}:arm64v8-${SEMVER} || :
              fi
              docker rmi \
                ghcr.io/imagegenius/igdev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :
             '''
      }
    }
    // If this is a public release tag it in the IG Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "3.17"
        expression {
          env.IG_RELEASE != env.EXT_RELEASE_CLEAN + '-ig' + env.IG_TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${META_TAG}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${IG_USER}/${IG_REPO}/git/tags \
        -d '{"tag":"'${META_TAG}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-ig'${IG_TAG_NUMBER}' to 3.17",\
             "type": "commit",\
             "tagger": {"name": "ImageGenius Jenkins","email": "ci@imagegenius.io","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#!/bin/bash
              echo "Updating base packages to ${PACKAGE_TAG}" > releasebody.json
              echo '{"tag_name":"'${META_TAG}'",\
                     "target_commitish": "3.17",\
                     "name": "'${META_TAG}'",\
                     "body": "**ImageGenius Changes:**\\n\\n'${IG_RELEASE_NOTES}'\\n\\n**OS Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": false}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${IG_USER}/${IG_REPO}/releases -d @releasebody.json.done'''
      }
    }
    // If this is a Pull request send the CI link as a comment on it
    stage('Pull Request Comment') {
      when {
        not {environment name: 'CHANGE_ID', value: ''}
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${IG_USER}/${IG_REPO}/issues/${PULL_REQUEST}/comments \
        -d '{"body": "I am a bot, here are the test results for this PR: \\n'${CI_URL}'"}' '''
      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
        if (env.EXIT_STATUS == "ABORTED"){
          sh 'echo "build aborted"'
        }
        else if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 1681177,\
                 "description": "**'${IG_REPO}'**\\n**Build**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 16711680,\
                 "description": "**'${IG_REPO}'**\\n**Build**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**Status:**  Failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
}
