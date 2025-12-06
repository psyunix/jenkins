# 🔧 Docker Socket Permission Issues in Jenkins

When Jenkins runs inside a Docker container and tries to build Docker images, it needs access to the Docker daemon socket (`/var/run/docker.sock`). This document explains the issue and provides solutions.

## The Problem

```
ERROR: permission denied while trying to connect to the Docker daemon socket 
at unix:///var/run/docker.sock: Head "http://%2Fvar%2Frun%2Fdocker.sock/_ping": 
dial unix /var/run/docker.sock: connect: permission denied
```

**Root cause:** The Jenkins process (running as the `jenkins` user inside the container) doesn't have read/write permissions on the Docker socket.

---

## Solution 1: Add Jenkins User to Docker Group (Quick Fix)

Inside the Jenkins container, add the `jenkins` user to the `docker` group:

### Step 1: Access the Jenkins container
```bash
docker exec -u root -it jenkins /bin/bash
```

### Step 2: Add jenkins user to docker group
```bash
usermod -aG docker jenkins
```

### Step 3: Restart Jenkins
```bash
exit  # exit the container
docker restart jenkins
```

### Step 4: Verify
```bash
docker exec jenkins docker ps
```

**Pros:** Simple, quick fix.  
**Cons:** Permissions are lost if the container restarts (not persistent).

---

## Solution 2: Mount Docker Socket Correctly (Persistent)

Ensure the `docker-compose.yml` mounts the Docker socket with correct permissions:

### Update `docker-compose.yml`

```yaml
services:
  jenkins:
    build:
      context: .
      dockerfile: Dockerfile.jenkins
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock  # ← Mount Docker socket
      - /usr/bin/docker:/usr/bin/docker              # ← Also mount Docker CLI binary
    networks:
      - jenkins-network
```

### Verify socket permissions on the host

On your host machine (where Docker is running):

```bash
ls -l /var/run/docker.sock
# Output should show: srw-rw---- root docker

# Ensure your user (or the Docker daemon) has access
sudo usermod -aG docker $(whoami)
newgrp docker  # Apply the new group membership
```

### Restart Jenkins
```bash
docker-compose down
docker-compose up -d
```

### Verify
```bash
docker-compose exec jenkins docker ps
```

**Pros:** Persistent; survives container restarts.  
**Cons:** Requires updating docker-compose.yml and rebuilding.

---

## Solution 3: Update Dockerfile.jenkins (Permanent)

If you want Docker access baked into the image, modify the Dockerfile to add the jenkins user to the docker group at build time:

### Update `Dockerfile.jenkins`

```dockerfile
FROM jenkins/jenkins:lts

# ... existing RUN commands ...

# Install Docker CLI
RUN apt-get update && apt-get install -y \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Add jenkins user to docker group
RUN usermod -aG docker jenkins

USER jenkins
```

Then rebuild:

```bash
docker-compose build jenkins
docker-compose up -d
```

**Pros:** Permanent; baked into the image; no need to modify docker-compose.yml.  
**Cons:** Requires a rebuild of the image.

---

## Solution 4: Run Jenkins with Extra Privileges (Not Recommended)

As a last resort, run Jenkins with elevated privileges:

```bash
docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock jenkins/jenkins:lts
```

**Pros:** Always works.  
**Cons:** Security risk; Jenkins gains host-level privileges.

---

## Diagnose the Issue

Use the provided diagnostic script to check permissions:

```bash
chmod +x scripts/check-docker-permissions.sh
docker-compose exec jenkins /tmp/check-docker-permissions.sh
```

Or copy it into the container and run:

```bash
docker cp scripts/check-docker-permissions.sh jenkins:/tmp/
docker exec jenkins bash /tmp/check-docker-permissions.sh
```

---

## Quick Checklist

- [ ] Docker socket is mounted in docker-compose.yml: `-v /var/run/docker.sock:/var/run/docker.sock`
- [ ] Jenkins user is in the docker group: `docker exec jenkins groups jenkins | grep docker`
- [ ] Docker CLI is installed in Jenkins container: `docker exec jenkins which docker`
- [ ] Jenkins container is running with access to the socket: `docker exec jenkins docker ps`

---

## Testing Your Fix

After applying a solution, run a Jenkins job that uses Docker:

1. Go to Jenkins: http://localhost:8080
2. Create or run a Pipeline job that includes:
   ```groovy
   stage('Test Docker') {
       steps {
           sh 'docker ps'
           sh 'docker --version'
       }
   }
   ```
3. If the build succeeds, Docker access is working ✅

---

## Production Considerations

For production Jenkins deployments:

- **Never** use `--privileged`.
- Use **Solution 2** (mount socket) or **Solution 3** (update Dockerfile) for persistent setups.
- Consider running a separate Docker-in-Docker (DinD) sidecar for enhanced isolation.
- Use Jenkins agents/nodes with Docker pre-configured instead of running Docker inside Jenkins itself.

---

## Further Reading

- [Docker Socket Security](https://docs.docker.com/engine/security/protect-client/)
- [Jenkins Docker Plugin](https://plugins.jenkins.io/docker-plugin/)
- [Dockerfile.jenkins](../Dockerfile.jenkins)
- [docker-compose.yml](../docker-compose.yml)
