# 📚 Jenkins Pipeline Examples

This directory contains example Jenkinsfiles you can use as templates for your own Jenkins jobs.

## Available Examples

### 1. `Jenkinsfile` — Real Web App with Database (Smoke Tests)

A complete end-to-end pipeline that:
- Builds the `webserver` Docker image
- Starts a temporary MariaDB container
- Initializes the database (if script available)
- Runs the web server and performs smoke tests against `/` and `/db-test.php`
- Cleans up containers

**Use when:** You want to test the full web stack locally in Jenkins.

**Key stages:** Checkout → Build Image → Start MariaDB → Init DB → Start Webserver → Smoke Tests → Cleanup

**Requirements:** Jenkins agent with Docker CLI access.

**Run it:**
```bash
# Via UI: create Pipeline job, set Script Path to example/Jenkinsfile
# Or via API: use jenkins_jobs/create_jenkins_job.sh
```

---

### 2. `Jenkinsfile-ghcr` — Build and Push to GitHub Container Registry

A production-ready pipeline that:
- Builds the webserver image
- Tests installed tools (vim, mc, curl, etc.)
- Logs into GitHub Container Registry (GHCR)
- Pushes images with `latest` and `build-${BUILD_NUMBER}` tags
- Cleans up and logs out

**Use when:** You want to automate image builds and publish them to GHCR for external use.

**Key stages:** Checkout → Build Image → Test Image → Login to GHCR → Push to GHCR → Cleanup

**Requirements:** 
- Jenkins agent with Docker CLI access
- Jenkins credential named `github-packages` (GitHub token with `write:packages` scope)

**Setup credentials in Jenkins:**
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **Add Credentials** (or select a domain)
3. Choose **Username with password**
4. Username: your GitHub username
5. Password: a GitHub personal access token with `write:packages` scope
6. ID: `github-packages`
7. Click **Save**

**Run it:**
```bash
# Via UI: create Pipeline job, set Script Path to example/Jenkinsfile-ghcr
# Or create a job XML similar to jenkins_jobs/example-pipeline-config.xml
# but with scriptPath set to example/Jenkinsfile-ghcr
```

**Published images appear at:**
```
ghcr.io/psyunix/jenkins/webserver:latest
ghcr.io/psyunix/jenkins/webserver:build-123
```

View them at: https://github.com/psyunix/jenkins/pkgs/container/jenkins%2Fwebserver

---

## How to Create a Job from These Examples

### Option A: Via Jenkins Web UI

1. Go to Jenkins home (`http://localhost:8080`)
2. Click **New Item**
3. Enter a name (e.g., `Example-Webapp-Test`)
4. Choose **Pipeline** and click **OK**
5. Under **Pipeline**, choose **Pipeline script from SCM**
6. Select **Git** as the SCM
7. Repository URL: `https://github.com/psyunix/jenkins.git`
8. Branch: `*/main`
9. Script Path: `example/Jenkinsfile` (or `example/Jenkinsfile-ghcr` for GHCR variant)
10. Click **Save**
11. Click **Build Now** to run the pipeline

### Option B: Programmatically (using the script)

From the repo root:

```bash
chmod +x jenkins_jobs/create_jenkins_job.sh
export JENKINS_URL="https://your-jenkins.example.com"
export JENKINS_USER="your-username"
export JENKINS_TOKEN="your-api-token"
./jenkins_jobs/create_jenkins_job.sh example-webapp-test
```

(Note: this uses `jenkins_jobs/example-pipeline-config.xml` which points to `example/Jenkinsfile` by default. Adapt the config if you want to use `example/Jenkinsfile-ghcr`.)

---

## Customizing the Examples

### Change Docker Image Names/Tags

Edit the `environment` block in the Jenkinsfile:

```groovy
environment {
    GHCR_REGISTRY = 'ghcr.io'
    GHCR_REPO = 'your-org/your-project'  // Change here
    IMAGE_NAME = 'webserver'              // or here
}
```

### Adjust Test Commands

In the **Test Image** stage, modify the `docker run` commands to test different tools or versions:

```groovy
stage('Test Image') {
    steps {
        script {
            sh '''
                docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest java -version
                docker run --rm ${GHCR_REGISTRY}/${GHCR_REPO}/${IMAGE_NAME}:latest python3 --version
            '''
        }
    }
}
```

### Add More Smoke Tests

In the **Smoke Tests** stage (web app example), add more curl assertions:

```groovy
stage('Smoke Tests') {
    steps {
        sh '''
            # Check HTTP status code
            curl -f http://localhost:8082/ || exit 1
            
            # Check specific content
            curl -s http://localhost:8082/ | grep -q "Welcome" || exit 1
            
            # Check DB connectivity
            curl -f http://localhost:8082/db-test.php || exit 1
        '''
    }
}
```

---

## Troubleshooting

### "Docker: permission denied"

The Jenkins user needs access to the Docker socket. On the Jenkins agent:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins  # or docker restart jenkins
```

### "docker login: authentication failed"

Verify your GitHub token has the correct scope (`write:packages` or `repo`). Check the credential in Jenkins at **Manage Jenkins** → **Manage Credentials** → find `github-packages`.

### "Failed to push image: image not found"

Ensure the image was built successfully in the **Build Image** stage. Check the build logs for errors.

---

## Next Steps

- Link these jobs to GitHub webhooks to trigger automatically on push
- Add notifications (email, Slack) to the `post` block
- Extend with artifact storage, SAST/SCA scanning, or deployment stages
- Convert to Multibranch Pipeline to automatically test PRs and branches

---

**Questions or issues?** Check the main [README.md](../README.md) and [JENKINS_JOBS_TUTORIAL.md](../JENKINS_JOBS_TUTORIAL.md) for more details on Jenkins setup and production guidance.
