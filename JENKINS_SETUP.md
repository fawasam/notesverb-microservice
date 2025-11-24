# Jenkins Setup Guide for Microservices Pipeline

This guide outlines all the prerequisites and steps needed before running the Jenkinsfile pipeline.

## Prerequisites

### 1. Jenkins Installation & Access
- [ ] Jenkins server installed and running
- [ ] Access to Jenkins dashboard (admin credentials)
- [ ] Jenkins version 2.x or higher recommended

---

## Required Jenkins Plugins

Install the following plugins via **Manage Jenkins → Plugins → Available Plugins**:

### Core Plugins
1. **Git Plugin** - For Git SCM integration
2. **Pipeline Plugin** - For pipeline support (usually pre-installed)
3. **Docker Pipeline Plugin** - For Docker commands in pipeline
4. **SSH Agent Plugin** - For GitOps repository authentication
5. **Credentials Binding Plugin** - For managing secrets

### Optional but Recommended
6. **Blue Ocean** - Modern UI for pipelines
7. **Pipeline: Stage View** - Better visualization
8. **Timestamper** - Adds timestamps to console output

### Installation Steps:
```
1. Navigate to: Manage Jenkins → Plugins
2. Click "Available plugins" tab
3. Search for each plugin listed above
4. Check the box next to each plugin
5. Click "Install" (choose "Install without restart" or "Download now and install after restart")
6. Wait for installation to complete
```

---

## Required Credentials Setup

### 1. Docker Registry Credentials

**Purpose:** Authenticate with Docker Hub to push images

**Steps:**
1. Go to **Manage Jenkins → Credentials → System → Global credentials**
2. Click **Add Credentials**
3. Configure:
   - **Kind:** Username with password
   - **Scope:** Global
   - **Username:** `fawaswebcastle` (your Docker Hub username)
   - **Password:** Your Docker Hub access token/password
   - **ID:** `docker-registry-credentials` (recommended)
   - **Description:** Docker Hub credentials

> [!IMPORTANT]
> Use a Docker Hub **Access Token** instead of your password for better security.
> Generate one at: https://hub.docker.com/settings/security

### 2. GitOps SSH Key

**Purpose:** Authenticate with your GitOps repository for pushing updates

**Steps:**

#### A. Generate SSH Key (if you don't have one)
```bash
# On your local machine or Jenkins server
ssh-keygen -t ed25519 -C "jenkins@gitops" -f ~/.ssh/jenkins_gitops
# Press Enter for no passphrase (or set one if preferred)
```

#### B. Add Public Key to GitHub
1. Copy the public key:
   ```bash
   cat ~/.ssh/jenkins_gitops.pub
   ```
2. Go to your GitOps repository: https://github.com/fawasam/notesverb-gitops
3. Navigate to **Settings → Deploy keys**
4. Click **Add deploy key**
5. Configure:
   - **Title:** Jenkins CI/CD
   - **Key:** Paste the public key content
   - **Allow write access:** ✓ (MUST be checked)
6. Click **Add key**

#### C. Add Private Key to Jenkins
1. Copy the private key:
   ```bash
   cat ~/.ssh/jenkins_gitops
   ```
2. In Jenkins: **Manage Jenkins → Credentials → System → Global credentials**
3. Click **Add Credentials**
4. Configure:
   - **Kind:** SSH Username with private key
   - **Scope:** Global
   - **ID:** `gitops-ssh-key` (MUST match the Jenkinsfile)
   - **Description:** GitOps repository SSH key
   - **Username:** `git`
   - **Private Key:** Select "Enter directly" and paste the private key
   - **Passphrase:** Enter if you set one during key generation
5. Click **Create**

---

## Docker Configuration

### 1. Docker Installation on Jenkins Server

Ensure Docker is installed on the Jenkins server:
```bash
docker --version
```

If not installed, follow: https://docs.docker.com/engine/install/

### 2. Jenkins User Docker Permissions

The Jenkins user must have permission to run Docker commands:

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins service
sudo systemctl restart jenkins
```

### 3. Docker Login (Alternative Method)

If you prefer to pre-authenticate Docker on the Jenkins server:
```bash
# Login as jenkins user
sudo su - jenkins
docker login docker.io
# Enter username: fawaswebcastle
# Enter password/token
```

---

## Additional Tools Installation

### 1. yq - YAML Processor

The pipeline uses `yq` to update Kubernetes manifests.

**Install on Jenkins Server:**
```bash
# For Linux (adjust version as needed)
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq

# Verify installation
yq --version
```

**For macOS:**
```bash
brew install yq
```

### 2. Git Configuration

Ensure Git is configured on the Jenkins server:
```bash
git config --global user.email "jenkins@ci.local"
git config --global user.name "Jenkins CI"
```

---

## Pipeline Configuration

### 1. Create Jenkins Pipeline Job

1. Go to Jenkins dashboard
2. Click **New Item**
3. Enter name: `microservices-cicd` (or your preferred name)
4. Select **Pipeline**
5. Click **OK**

### 2. Configure Pipeline

#### General Settings
- **Description:** CI/CD pipeline for microservices deployment
- **GitHub project:** (Optional) `https://github.com/fawasam/notesverb-microservice`

#### Build Triggers (Optional)
- ☑ **GitHub hook trigger for GITScm polling** (for automatic builds on push)
- ☑ **Poll SCM** with schedule: `H/5 * * * *` (checks every 5 minutes)

#### Pipeline Definition
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** Your microservice repository URL
- **Credentials:** Select appropriate Git credentials if private
- **Branch Specifier:** `*/dev` (or your default branch)
- **Script Path:** `Jenkinsfile`

### 3. Save Configuration

Click **Save** to create the pipeline.

---

## Pre-Flight Checklist

Before running the pipeline, verify:

- [ ] All required plugins installed
- [ ] Docker registry credentials configured with ID matching your Jenkinsfile
- [ ] GitOps SSH key configured with ID: `gitops-ssh-key`
- [ ] Docker installed and Jenkins user has permissions
- [ ] `yq` tool installed and accessible
- [ ] Git configured with user name and email
- [ ] GitOps repository deploy key added with write access
- [ ] All services have Dockerfiles in their directories
- [ ] GitOps repository structure matches expected paths

---

## Testing the Setup

### 1. Test Docker Access
Create a test pipeline job with:
```groovy
pipeline {
    agent any
    stages {
        stage('Test Docker') {
            steps {
                sh 'docker --version'
                sh 'docker ps'
            }
        }
    }
}
```

### 2. Test SSH Access to GitOps
```groovy
pipeline {
    agent any
    stages {
        stage('Test SSH') {
            steps {
                sshagent(['gitops-ssh-key']) {
                    sh 'ssh -T git@github.com || true'
                }
            }
        }
    }
}
```

### 3. Test yq Installation
```groovy
pipeline {
    agent any
    stages {
        stage('Test yq') {
            steps {
                sh 'yq --version'
            }
        }
    }
}
```

---

## Pipeline Modifications Needed

Your current Jenkinsfile needs a small update for Docker authentication. Here's what to add:

### Add Docker Login Step

After the `Checkout` stage, add:

```groovy
stage('Docker Login') {
  steps {
    script {
      withCredentials([usernamePassword(
        credentialsId: 'docker-registry-credentials',
        usernameVariable: 'DOCKER_USER',
        passwordVariable: 'DOCKER_PASS'
      )]) {
        sh 'echo $DOCKER_PASS | docker login docker.io -u $DOCKER_USER --password-stdin'
      }
    }
  }
}
```

> [!WARNING]
> Without this step, the `docker push` commands will fail with authentication errors.

---

## Repository Structure Verification

Ensure your repositories have the expected structure:

### Microservices Repository
```
ms-deploy/
├── Jenkinsfile
├── api-gateway/
│   └── Dockerfile
└── services/
    ├── auth-service/
    │   └── Dockerfile
    ├── notes-service/
    │   └── Dockerfile
    ├── tags-service/
    │   └── Dockerfile
    └── user-service/
        └── Dockerfile
```

### GitOps Repository
```
notesverb-gitops/
└── services/
    ├── api-gateway/
    │   └── overlays/
    │       ├── dev/
    │       │   └── kustomization.yaml
    │       ├── staging/
    │       │   └── kustomization.yaml
    │       └── prod/
    │           └── kustomization.yaml
    ├── auth-service/
    │   └── overlays/...
    ├── notes-service/
    │   └── overlays/...
    ├── tags-service/
    │   └── overlays/...
    └── user-service/
        └── overlays/...
```

---

## Running the Pipeline

Once all prerequisites are met:

1. Go to your pipeline job in Jenkins
2. Click **Build Now**
3. Monitor the build in **Console Output**
4. Check each stage completes successfully

---

## Troubleshooting

### Common Issues

#### Docker Permission Denied
```
Error: permission denied while trying to connect to Docker daemon
```
**Solution:** Add jenkins user to docker group and restart Jenkins

#### SSH Authentication Failed
```
Error: Permission denied (publickey)
```
**Solution:** Verify SSH key is added to GitHub deploy keys with write access

#### yq Command Not Found
```
Error: yq: command not found
```
**Solution:** Install yq on Jenkins server

#### Docker Push Unauthorized
```
Error: unauthorized: authentication required
```
**Solution:** Add Docker login stage to pipeline

---

## Security Best Practices

1. **Use Access Tokens:** Never use plain passwords for Docker Hub
2. **Limit SSH Key Scope:** Use deploy keys instead of personal SSH keys
3. **Credential IDs:** Keep credential IDs consistent and documented
4. **Secrets Management:** Never hardcode credentials in Jenkinsfile
5. **Regular Updates:** Keep Jenkins and plugins updated

---

## Next Steps

After successful pipeline setup:

1. Test with a small code change
2. Verify images are pushed to Docker Hub
3. Verify GitOps repository is updated
4. Set up ArgoCD/Flux to watch GitOps repository
5. Configure webhooks for automatic builds

---

## Support Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Pipeline Plugin](https://plugins.jenkins.io/docker-workflow/)
- [SSH Agent Plugin](https://plugins.jenkins.io/ssh-agent/)
- [yq Documentation](https://mikefarah.gitbook.io/yq/)
