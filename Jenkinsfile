pipeline {
  agent any

  environment {
    DOCKER_REGISTRY_PREFIX = "docker.io/fawaswebcastle"
    GITOPS_REPO = "git@github.com:fawasam/notesverb-gitops.git"
    GITOPS_CLONE_DIR = "gitops"
    // list services (include api-gateway + services/*)
    SERVICES = "api-gateway services/auth-service services/notes-service services/tags-service services/user-service"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Docker Login') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'docker-registry-credentials',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh """
        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
          """
    }
        }
    }


    stage('Build & Push Images') {
      steps {
        script {
          // IMAGE_TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          IMAGE_TAG = "latest"
          env.IMAGE_TAG = IMAGE_TAG
          echo "IMAGE_TAG = ${IMAGE_TAG}"

          // build & push for each service
          for (svc in SERVICES.split()) {
            // compute image name (use folder name as image)
            def svcName = svc.tokenize('/').last()
            def image = "${DOCKER_REGISTRY_PREFIX}/${svcName}:${IMAGE_TAG}"
            echo "Building ${svc} -> ${image}"
            
            // Build from root directory with -f to specify Dockerfile location
            // This allows Dockerfile to access both shared/ and service directories
            sh """
              docker build -f ${svc}/Dockerfile -t ${image} .
              docker push ${image}
            """
          }
        }
      }
    }

    stage('Update GitOps Repo - Dev') {
      steps {
        sshagent(['gitops-ssh-key']) {
          script {
            sh """
              export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
              rm -rf ${GITOPS_CLONE_DIR}
              git clone ${GITOPS_REPO} ${GITOPS_CLONE_DIR}
            """

            // update overlays/dev for each service
            for (svc in SERVICES.split()) {
              def svcName = svc.tokenize('/').last()
              def overlayPath = "${GITOPS_CLONE_DIR}/services/${svcName}/overlays"
              // prefer dev overlay; if missing alert
              sh """
                if [ -d "${overlayPath}/dev" ]; then
                  yq e -i '.images[0].newTag = "${IMAGE_TAG}"' ${overlayPath}/dev/kustomization.yaml || true
                  git -C ${GITOPS_CLONE_DIR} add .
                else
                  echo "No dev overlay for ${svcName}, skipping."
                fi
              """
            }

            sh """
              cd ${GITOPS_CLONE_DIR}
              git commit -m "CI: update dev images to ${IMAGE_TAG}" || echo "no changes to commit"
              git push origin main || echo "push failed"
            """
          }
        }
      }
    }

    stage('Update GitOps Repo - Staging/Prod promotion') {
      when {
        anyOf {
          branch 'staging'
          branch 'main'
        }
      }
      steps {
        sshagent(['gitops-ssh-key']) {
          script {
            sh "export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no'; rm -rf ${GITOPS_CLONE_DIR}; git clone ${GITOPS_REPO} ${GITOPS_CLONE_DIR}"
            def target = (env.BRANCH_NAME == 'staging') ? 'staging' : 'prod'
            for (svc in SERVICES.split()) {
              def svcName = svc.tokenize('/').last()
              def overlayFile = "${GITOPS_CLONE_DIR}/services/${svcName}/overlays/${target}/kustomization.yaml"
              sh """
                if [ -f "${overlayFile}" ]; then
                  yq e -i '.images[0].newTag = "${IMAGE_TAG}"' ${overlayFile} || true
                  git -C ${GITOPS_CLONE_DIR} add .
                else
                  echo "No ${target} overlay for ${svcName}, skipping."
                fi
              """
            }
            sh """
              cd ${GITOPS_CLONE_DIR}
              git commit -m "CI: ${target} update images to ${IMAGE_TAG}" || echo "no changes to commit"
              git push origin main || echo "push failed"
            """
          }
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished"
    }
  }
}
