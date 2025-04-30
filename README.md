# Jenkins CI/CD Environment for Java, Python, and Go

This repository contains Docker configuration files to run Jenkins with support for building Java, Python, and Go applications. The setup includes Docker-in-Docker capability and Git webhook integration.

## Prerequisites

- Docker Engine (19.03.0+)
- Docker Compose (1.27.0+)
- Git

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd jenkins
   ```

2. Create the necessary directories:
   ```bash
   mkdir -p jenkins-init-scripts
   ```

3. Start Jenkins:
   ```bash
   docker-compose up -d
   ```

4. Access Jenkins at: http://localhost:8080/jenkins

## Setup Details

### Environment Components

- **Jenkins LTS**: The base Jenkins server
- **Build Tools**:
  - Java (Amazon Corretto 23)
  - Python 3 with pip and venv
  - Go 1.21.0
  - Maven
- **Docker-in-Docker**: Allows Jenkins to build Docker images

### Initial Configuration

The default admin password is available in the container logs:

```bash
docker logs jenkins | grep -A 3 "initialAdminPassword"
```

or:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Security Configuration

1. Access Jenkins and log in with the initial admin password
2. Follow the setup wizard to:
   - Install suggested plugins
   - Create an admin user
   - Configure the Jenkins URL

3. Configure security:
   - Go to **Manage Jenkins** > **Security**
   - Enable **Project-based Matrix Authorization Strategy**
   - Set up appropriate permissions for users and groups

### Network Considerations

For external access, consider:

1. Using a reverse proxy (like Nginx or Traefik)
2. Setting up SSL/TLS certificates
3. Configuring appropriate firewall rules

## Git Integration

### GitHub Webhooks

To set up GitHub webhooks:

1. In Jenkins, go to **Manage Jenkins** > **System** > **GitHub**
2. Add your GitHub credentials
3. Test the connection

4. In your GitHub repository:
   - Go to **Settings** > **Webhooks** > **Add webhook**
   - Payload URL: `http://<your-jenkins-url>/jenkins/github-webhook/`
   - Content type: `application/json`
   - Select events: "Just the push event" or customize as needed
   - Ensure "Active" is checked

### GitLab Webhooks

1. Install the GitLab plugin if not already installed
2. Configure GitLab connection in **Manage Jenkins** > **System** > **GitLab**
3. In your GitLab repository:
   - Go to **Settings** > **Webhooks**
   - URL: `http://<your-jenkins-url>/jenkins/gitlab-webhook/project`
   - Select trigger events (e.g., Push events, Merge request events)

### Bitbucket Webhooks

1. Install the Bitbucket plugin
2. Configure Bitbucket connection in **Manage Jenkins**
3. In your Bitbucket repository:
   - Go to **Repository settings** > **Webhooks** > **Add webhook**
   - URL: `http://<your-jenkins-url>/jenkins/bitbucket-hook/`
   - Choose the events to trigger the webhook

## Webhook Endpoints Reference

This Jenkins setup comes preconfigured to support webhook integrations with various Git providers. Below is a comprehensive list of available endpoints and how to use them.

### Available Webhook Endpoints

| Git Provider | Webhook URL | Format |
|-------------|-------------|--------|
| GitHub | `http://<your-jenkins-url>/jenkins/github-webhook/` | JSON |
| GitLab | `http://<your-jenkins-url>/jenkins/gitlab-webhook/project` | JSON |
| Bitbucket | `http://<your-jenkins-url>/jenkins/bitbucket-hook/` | JSON |
| Generic Git | `http://<your-jenkins-url>/jenkins/git/notifyCommit?url=<repository-url>` | GET parameter |

### Exposing Webhooks Behind a Reverse Proxy

If you're running Jenkins behind a reverse proxy (like Nginx, Apache, or Traefik), ensure that:

1. The proxy correctly forwards the `/jenkins` context path:
   ```nginx
   # Example Nginx configuration
   location /jenkins {
     proxy_pass http://jenkins:8080/jenkins;
     proxy_set_header Host $host;
     proxy_set_header X-Real-IP $remote_addr;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```

2. Configure the public URL in Jenkins:
   - Go to **Manage Jenkins** > **System** > **Jenkins Location**
   - Set the **Jenkins URL** to your public URL (e.g., `https://jenkins.example.com/jenkins`)

3. If using HTTPS, update webhook URLs to use `https://` instead of `http://`

### Security Considerations

1. **Authentication**: 
   - Use the Jenkins credential system to store Git provider API tokens
   - Consider enabling webhook secret validation (available for GitHub and GitLab)

2. **Authorization**:
   - Limit which users/systems can trigger builds via webhooks
   - In **Manage Jenkins** > **Security** > set appropriate permissions

3. **IP Restrictions**:
   - Consider restricting webhook access to IP ranges of your Git provider
   - Can be configured through a reverse proxy or firewall rules

4. **CSRF Protection**:
   - Webhooks are exempt from CSRF protection by default
   - No special configuration needed for the Git provider webhook endpoints

### Testing Webhooks

1. **Manual Testing**:
   - Use `curl` to send a test payload:
     ```bash
     curl -X POST http://localhost:8080/jenkins/github-webhook/ \
       -H "Content-Type: application/json" \
       -d '{"ref":"refs/heads/main"}'
     ```

2. **Provider Testing**:
   - GitHub: Use the "Test" button in webhook settings
   - GitLab: Use "Test" button in webhook configuration
   - Bitbucket: Use "Test connection" in webhook settings

3. **Troubleshooting**:
   - Check Jenkins logs for webhook payload reception
   - Enable additional webhook logging in **Manage Jenkins** > **System Log** > **Add new log recorder**
   - Name it "Webhook Debug" and add loggers for the Git integration plugins

4. **Payload Inspection**:
   - To debug webhook content, consider using a service like [webhook.site](https://webhook.site) as a temporary endpoint
   - Redirect your Git provider to webhook.site temporarily to inspect the payload structure

## Pipeline Examples

### Java Maven Project

Create a `Jenkinsfile` in your Java project repository:

```groovy
pipeline {
    agent any
    
    tools {
        maven 'Maven'
        jdk 'JDK'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }
        
        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Package') {
            steps {
                sh 'mvn package'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }
    }
}
```

### Python Project

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh '''
                python -m venv venv
                . venv/bin/activate
                pip install -r requirements.txt
                '''
            }
        }
        
        stage('Lint') {
            steps {
                sh '''
                . venv/bin/activate
                pip install flake8
                flake8 .
                '''
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                . venv/bin/activate
                pip install pytest
                pytest
                '''
            }
        }
        
        stage('Build') {
            steps {
                sh '''
                . venv/bin/activate
                pip install build
                python -m build
                '''
            }
            post {
                success {
                    archiveArtifacts artifacts: 'dist/*', fingerprint: true
                }
            }
        }
    }
}
```

### Go Project

```groovy
pipeline {
    agent any
    
    environment {
        GOPATH = "${WORKSPACE}/gopath"
        PATH = "${GOPATH}/bin:${PATH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh 'mkdir -p ${GOPATH}/src/${GO_PROJECT_PATH}'
                sh 'ln -sf ${WORKSPACE} ${GOPATH}/src/${GO_PROJECT_PATH}'
                sh 'go mod download'
            }
        }
        
        stage('Lint') {
            steps {
                sh 'go vet ./...'
                sh 'go install golang.org/x/lint/golint@latest'
                sh 'golint ./...'
            }
        }
        
        stage('Test') {
            steps {
                sh 'go test -v ./...'
            }
        }
        
        stage('Build') {
            steps {
                sh 'go build -o myapp'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'myapp', fingerprint: true
                }
            }
        }
    }
}
```

## Troubleshooting

### Common Issues

1. **Jenkins won't start**:
   - Check Docker logs: `docker-compose logs jenkins`
   - Ensure volume permissions are correct

2. **Cannot access Jenkins UI**:
   - Verify ports are correctly mapped: `docker-compose ps`
   - Check if Jenkins service is running: `docker-compose logs jenkins`

3. **Docker in Docker issues**:
   - Ensure the docker socket is correctly mounted
   - Verify the jenkins user has permissions to access the Docker socket:
     ```bash
     docker exec -it jenkins bash
     ls -la /var/run/docker.sock
     ```

4. **Plugin installation problems**:
   - Manually install plugins through the UI
   - Check network connectivity from inside the container

5. **Webhook not triggering builds**:
   - Verify webhook URL is correct
   - Check Jenkins logs for webhook payloads
   - Ensure appropriate firewall settings

## Maintenance

### Updating Jenkins

1. Update the images:
   ```bash
   docker-compose pull
   docker-compose down
   docker-compose up -d --build
   ```

### Backup and Restore

Backup Jenkins data:
```bash
docker run --rm -v jenkins_home:/jenkins_home -v $(pwd):/backup ubuntu tar czf /backup/jenkins_backup.tar.gz /jenkins_home
```

Restore from backup:
```bash
docker run --rm -v jenkins_home:/jenkins_home -v $(pwd):/backup ubuntu bash -c "cd /jenkins_home && tar xzf /backup/jenkins_backup.tar.gz --strip 1"
```

## License

[MIT License](LICENSE)

