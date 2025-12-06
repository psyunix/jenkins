# 🔧 Jenkins Job Tutorial - Installing Software on Web Server

This guide walks you through creating your first Jenkins job to install software on the web server and push the updated image to GitHub Container Registry !!!

## 📋 Table of Contents

1. [Initial Jenkins Setup](#initial-jenkins-setup)
2. [Create Your First Job](#create-your-first-job)
3. [Install Software via Dockerfile](#install-software-via-dockerfile)
4. [Test and Push to GHCR](#test-and-push-to-ghcr)
5. [Automate Monthly OS Updates](#automate-monthly-os-updates)

---

## 🚀 Initial Jenkins Setup

### Step 1: Access Jenkins

1. Open http://localhost:8080
2. If first time, you'll see the setup wizard
3. Get the initial password if needed:
   ```bash
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
4. Install suggested plugins
5. Create your first admin user

### Step 2: Install Required Plugins

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Click **Available** tab
3. Search and install:
   - **Docker Pipeline** (if not already installed)
   - **Git** (usually pre-installed)
   - **Pipeline** (usually pre-installed)
   - **Credentials Binding Plugin**

4. Restart Jenkins after installation

### Step 3: Configure Docker in Jenkins

Jenkins container already has Docker installed, but let's verify:

1. Go to **Manage Jenkins** → **System**
2. Verify Docker is accessible

---

## 🎯 Create Your First Job: Install vim, mc, and curl

### Method 1: Update Dockerfile (Recommended)

#### Step 1: Update the Web Server Dockerfile

Edit `/Users/psyunix/Documents/git/jenkins/Dockerfile.webserver`:

```dockerfile
# Use Ubuntu as base image
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install Apache, MariaDB, PHP, and other dependencies
RUN apt-get update && \
    apt-get install -y \
    apache2 \
    mariadb-server \
    php \
    php-mysql \
    libapache2-mod-php \
    curl \
    vim \
    mc \
    htop \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ... rest of the file remains the same
```

#### Step 2: Test Locally

```bash
cd /Users/psyunix/Documents/git/jenkins

# Rebuild the web server image
docker-compose build webserver

# Test it
docker-compose up -d

# Verify installations
docker exec webserver which vim
docker exec webserver which mc
docker exec webserver vim --version
```

#### Step 3: Commit and Push

```bash
git add Dockerfile.webserver
git commit -m "Add vim, mc, htop, and net-tools to web server"
git push
```

#### Step 4: Wait for GitHub Actions

The `build-images.yml` workflow will automatically:
- Build the new image
- Push to GHCR with the new software installed
- Tag it as `latest`

Check progress: https://github.com/psyunix/jenkins/actions

---

### Method 2: Create a Jenkins Pipeline Job

If you want Jenkins to handle the build and push:

#### Step 1: Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click **Generate new token** → **Generate new token (classic)**
3. Name: `Jenkins GHCR Access`
4. Select scopes:
   - `write:packages`
   - `read:packages`
   - `delete:packages` (optional)
5. Click **Generate token**
6. **Copy the token** - you won't see it again!

#### Step 2: Add Credentials to Jenkins

1. In Jenkins, go to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** → **Add Credentials**
3. Fill in:
   - **Kind:** Username with password
   - **Username:** `psyunix`
   - **Password:** [Your GitHub Personal Access Token]
   - **ID:** `github-packages`
   - **Description:** `GitHub Container Registry`
4. Click **OK**

#### Step 3: Create Jenkins Pipeline Job

1. Click **New Item**
2. Enter name: `Build-and-Push-WebServer`
3. Select **Pipeline**
4. Click **OK**

#### Step 4: Configure the Pipeline

In the **Pipeline** section, paste this script:

```groovy
pipeline {
    agent any
    
    environment {
        GHCR_REGISTRY = 'ghcr.io'
        GHCR_REPO = 'psyunix/jenkins'
        IMAGE_NAME = 'webserver'
        DOCKER_CREDENTIALS = 'github-packages'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/psyunix/jenkins.git'
            }
        }
        
        stage('Build Image') {
            steps {
                script {
                    echo 'Building Web Server Docker image...'
                    sh 'docker build -f Dockerfile.webserver -t ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest .'
                }
            }
        }
        
        stage('Test Image') {
            steps {
                script {
                    echo 'Testing if software is installed...'
                    sh '''
                        docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest which vim
                        docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest which mc
                        docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest curl --version
                    '''
                }
            }
        }
        
        stage('Login to GHCR') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: env.DOCKER_CREDENTIALS,
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'PASSWORD'
                    )]) {
                        sh 'echo $PASSWORD | docker login ${GHCR_REGISTRY} -u $USERNAME --password-stdin'
                    }
                }
            }
        }
        
        stage('Push to GHCR') {
            steps {
                script {
                    echo 'Pushing image to GitHub Container Registry...'
                    sh 'docker push ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest'
                    
                    // Tag with build number
                    sh """
                        docker tag ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest \
                                   ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:build-${BUILD_NUMBER}
                        docker push ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:build-${BUILD_NUMBER}
                    """
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    echo 'Cleaning up local images...'
                    sh 'docker logout ${GHCR_REGISTRY}'
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Image built and pushed successfully!'
        }
        failure {
            echo '❌ Build failed!'
        }
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
        }
    }
}
```

#### Step 5: Save and Run

1. Click **Save**
2. Click **Build Now**
3. Watch the **Console Output** to see the build progress
4. Once complete, your new image will be in GHCR!

---

## 🔄 Automate Monthly OS Updates

### Create Jenkins Job for Monthly Updates

#### Step 1: Create New Pipeline Job

1. Click **New Item**
2. Name: `Monthly-WebServer-Update`
3. Select **Pipeline**
4. Click **OK**

#### Step 2: Configure Schedule

In **Build Triggers**, check **Build periodically**

Schedule expression (runs at 2 AM on the 1st of every month):
```
0 2 1 * *
```

Schedule expressions:
- `0 2 1 * *` - 2 AM on the 1st of each month
- `0 3 * * 0` - 3 AM every Sunday
- `0 4 15 * *` - 4 AM on the 15th of each month

#### Step 3: Pipeline Script for Updates

```groovy
pipeline {
    agent any
    
    environment {
        GHCR_REGISTRY = 'ghcr.io'
        GHCR_REPO = 'psyunix/jenkins'
        IMAGE_NAME = 'webserver'
        DOCKER_CREDENTIALS = 'github-packages'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/psyunix/jenkins.git'
            }
        }
        
        stage('Create Updated Dockerfile') {
            steps {
                script {
                    // Create a temporary Dockerfile with update commands
                    sh '''
                        cat > Dockerfile.webserver.updated << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and upgrade all packages
RUN apt-get update && \\
    apt-get upgrade -y && \\
    apt-get install -y \\
    apache2 \\
    mariadb-server \\
    php \\
    php-mysql \\
    libapache2-mod-php \\
    curl \\
    vim \\
    mc \\
    htop \\
    net-tools \\
    && apt-get autoremove -y \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite php8.1

# Copy application files
COPY webserver/index.php /var/www/html/
COPY webserver/db-test.php /var/www/html/
COPY webserver/init-db.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-db.sh

COPY webserver/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 80

CMD ["/usr/local/bin/start.sh"]
EOF
                    '''
                }
            }
        }
        
        stage('Build Updated Image') {
            steps {
                script {
                    echo 'Building updated Web Server image with latest packages...'
                    sh """
                        docker build -f Dockerfile.webserver.updated \\
                            -t ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest \\
                            -t ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:update-${BUILD_TIMESTAMP} \\
                            .
                    """
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    echo 'Running basic security checks...'
                    sh """
                        docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest \\
                            bash -c 'apt-get update && apt-get --just-print upgrade'
                    """
                }
            }
        }
        
        stage('Test Updated Image') {
            steps {
                script {
                    echo 'Testing updated image...'
                    sh """
                        # Start test container
                        docker run -d --name test-webserver -p 8082:80 \\
                            ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest
                        
                        # Wait for it to start
                        sleep 10
                        
                        # Test web server
                        curl -f http://localhost:8082/ || exit 1
                        
                        # Cleanup
                        docker stop test-webserver
                        docker rm test-webserver
                    """
                }
            }
        }
        
        stage('Login to GHCR') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: env.DOCKER_CREDENTIALS,
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'PASSWORD'
                    )]) {
                        sh 'echo $PASSWORD | docker login ${GHCR_REGISTRY} -u $USERNAME --password-stdin'
                    }
                }
            }
        }
        
        stage('Push Updated Image') {
            steps {
                script {
                    echo 'Pushing updated image to GHCR...'
                    sh """
                        docker push ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest
                        docker push ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:update-${BUILD_TIMESTAMP}
                    """
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    sh '''
                        docker logout ${GHCR_REGISTRY}
                        rm -f Dockerfile.webserver.updated
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Monthly update completed successfully!'
            echo "New image: ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:update-${BUILD_TIMESTAMP}"
        }
        failure {
            echo '❌ Monthly update failed!'
        }
        always {
            sh 'docker system prune -f'
        }
    }
}
```

#### Step 4: Save and Test

1. Click **Save**
2. Click **Build Now** to test it manually
3. Check the Console Output

---

## 📊 Monitor Your Jobs

### View Build History

1. Click on your job name
2. See **Build History** on the left
3. Click on any build number
4. Click **Console Output** to see logs

### Build Status

- **Blue ball** ✅ - Success
- **Red ball** ❌ - Failure
- **Yellow ball** ⚠️ - Unstable
- **Gray ball** ⏸️ - Aborted/Not built

---

## 🎯 Example: Simple Manual Job

### Quick Job to Install Software

1. **New Item** → Name: `Install-Tools` → **Freestyle project**
2. In **Build Steps**, click **Add build step** → **Execute shell**
3. Paste:
   ```bash
   # Update Dockerfile
   cd /var/jenkins_home/workspace/Install-Tools
   
   # Clone if not exists
   if [ ! -d ".git" ]; then
       git clone https://github.com/psyunix/jenkins.git .
   fi
   
   # Add tools to Dockerfile
   sed -i '/curl \\/a\    vim \\' Dockerfile.webserver
   sed -i '/vim \\/a\    mc \\' Dockerfile.webserver
   
   # Build
   docker build -f Dockerfile.webserver -t ghcr.io/psyunix/jenkins/webserver:latest .
   
   # Test
   docker run --rm ghcr.io/psyunix/jenkins/webserver:latest which vim
   
   echo "✅ Build complete!"
   ```

4. **Save** and **Build Now**

---

## 🔍 Verify Your New Image

After the job completes:

```bash
# Pull the new image
docker pull ghcr.io/psyunix/jenkins/webserver:latest

# Test it
docker run --rm ghcr.io/psyunix/jenkins/webserver:latest vim --version
docker run --rm ghcr.io/psyunix/jenkins/webserver:latest mc --version

# Or start your stack with the new image
docker-compose -f docker-compose.ghcr.yml pull
docker-compose -f docker-compose.ghcr.yml up -d --force-recreate
```

---

## 📝 Best Practices

### 1. Always Test Before Pushing

```groovy
stage('Test') {
    steps {
        sh 'docker run --rm ${IMAGE} /path/to/test-script.sh'
    }
}
```

### 2. Use Build Numbers for Tagging

```groovy
docker tag myimage:latest myimage:build-${BUILD_NUMBER}
```

### 3. Clean Up After Builds

```groovy
post {
    always {
        sh 'docker system prune -f'
    }
}
```

### 4. Use Credentials Securely

Never hardcode passwords! Always use Jenkins credentials:

```groovy
withCredentials([usernamePassword(...)]) {
    // Use $USERNAME and $PASSWORD here
}
```

### 5. Enable Notifications

Install **Email Extension Plugin** or **Slack Notification Plugin** to get alerts when builds fail.

---

## 🚀 Next Steps

1. ✅ Create your first job following this guide
2. ✅ Set up automated monthly updates
3. ✅ Configure email notifications
4. ✅ Explore more Jenkins plugins
5. ✅ Create multi-stage pipelines

---

## 📚 Additional Resources

- **Jenkins Pipeline Syntax:** https://www.jenkins.io/doc/book/pipeline/syntax/
- **Docker Pipeline Plugin:** https://plugins.jenkins.io/docker-workflow/
- **Cron Schedule Examples:** https://crontab.guru/

---

**Happy automating!** 🎉
