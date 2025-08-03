#!/bin/bash

set -e

# Configuration variables
PROJECT_NAME="privacy-pi"
WIREGUARD_PORT=51820
DASHBOARD_PORT=3000
GITHUB_REPO="https://github.com/your-username/privacy-pi.git"

# Function to check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script with sudo or as root."
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    apt-get update
    apt-get install -y docker.io docker-compose curl git nodejs npm
}

# Function to create project structure
create_project_structure() {
    mkdir -p $PROJECT_NAME/{services,configs,scripts,public}
    cd $PROJECT_NAME
}

# Function to create base Dockerfile
create_base_dockerfile() {
    cat > Dockerfile << EOF
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget gnupg iptables sudo nodejs npm \
    pihole wireguard unbound tor privoxy \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services /app/services
COPY scripts /app/scripts
COPY configs /app/configs
RUN chmod +x /app/scripts/*.sh /app/services/*.sh

CMD ["/app/scripts/start.sh"]
EOF
}

# Function to create docker-compose.yml
create_docker_compose() {
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  privacy-pi:
    build: .
    ports:
      - "${DASHBOARD_PORT}:${DASHBOARD_PORT}"
      - "${WIREGUARD_PORT}:${WIREGUARD_PORT}/udp"
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "443:443/tcp"
    cap_add:
      - NET_ADMIN
    volumes:
      - ./configs:/app/configs
      - ./services:/app/services
    environment:
      - TZ=UTC
    restart: unless-stopped
EOF
}

# Function to create service scripts
create_service_scripts() {
    # Create service setup scripts here (pihole, wireguard, unbound, tor, privoxy)
    # Example for Pi-hole:
    cat > services/setup_pihole.sh << EOF
#!/bin/bash
pihole -a -p
EOF
    # Create similar scripts for other services
    chmod +x services/*.sh
}

# Function to create Node.js server file
create_nodejs_server() {
    cat > server.js << EOF
const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const services = ['pihole', 'wireguard', 'unbound', 'tor', 'privoxy'];

function runCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(\`Error: \${error.message}\`);
        return;
      }
      if (stderr) {
        reject(\`stderr: \${stderr}\`);
        return;
      }
      resolve(stdout);
    });
  });
}

app.get('/api/status', async (req, res) => {
  try {
    const statuses = await Promise.all(services.map(async (service) => {
      const status = await runCommand(\`sudo systemctl is-active \${service}\`);
      return { [service]: status.trim() === 'active' };
    }));
    res.json(Object.assign({}, ...statuses));
  } catch (error) {
    res.status(500).json({ error: error.toString() });
  }
});

app.post('/api/toggle-service', async (req, res) => {
  const { service, action } = req.body;
  if (!services.includes(service) || !['start', 'stop', 'restart'].includes(action)) {
    return res.status(400).json({ error: 'Invalid service or action' });
  }
  try {
    await runCommand(\`sudo systemctl \${action} \${service}\`);
    res.json({ success: true, message: \`\${service} \${action}ed successfully\` });
  } catch (error) {
    res.status(500).json({ error: error.toString() });
  }
});

app.get('/api/logs/:service', async (req, res) => {
  const { service } = req.params;
  if (!services.includes(service)) {
    return res.status(400).json({ error: 'Invalid service' });
  }
  try {
    const logs = await fs.readFile(\`/var/log/\${service}.log\`, 'utf8');
    res.json({ logs: logs.split('\\n').slice(-100).join('\\n') });
  } catch (error) {
    res.status(500).json({ error: error.toString() });
  }
});

app.listen(port, () => {
  console.log(\`Privacy Pi server listening at http://localhost:\${port}\`);
});
EOF
}

# Function to create dashboard HTML
create_dashboard_html() {
    cat > public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Pi Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
</head>
<body class="bg-gray-100">
    <div id="app" class="container mx-auto p-4">
        <h1 class="text-3xl font-bold mb-4">Privacy Pi Dashboard</h1>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div v-for="(status, service) in statuses" :key="service" class="bg-white p-4 rounded shadow">
                <h2 class="text-xl font-semibold mb-2">{{ service }}</h2>
                <p :class="{'text-green-500': status, 'text-red-500': !status}">
                    Status: {{ status ? 'Running' : 'Stopped' }}
                </p>
                <button @click="toggleService(service)" class="mt-2 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                    {{ status ? 'Stop' : 'Start' }}
                </button>
            </div>
        </div>
        <div class="mt-8">
            <h2 class="text-2xl font-bold mb-4">System Logs</h2>
            <select v-model="selectedService" @change="fetchLogs" class="mb-2 p-2 border rounded">
                <option v-for="service in Object.keys(statuses)" :key="service" :value="service">
                    {{ service }}
                </option>
            </select>
            <pre class="bg-black text-green-400 p-4 rounded overflow-x-auto">{{ logs }}</pre>
        </div>
    </div>
    <script>
        const { createApp, ref, onMounted } = Vue;

        createApp({
            setup() {
                const statuses = ref({});
                const logs = ref('');
                const selectedService = ref('');

                const fetchStatus = async () => {
                    const response = await fetch('/api/status');
                    statuses.value = await response.json();
                };

                const toggleService = async (service) => {
                    const action = statuses.value[service] ? 'stop' : 'start';
                    await fetch('/api/toggle-service', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ service, action }),
                    });
                    await fetchStatus();
                };

                const fetchLogs = async () => {
                    if (selectedService.value) {
                        const response = await fetch(\`/api/logs/\${selectedService.value}\`);
                        const data = await response.json();
                        logs.value = data.logs;
                    }
                };

                onMounted(fetchStatus);

                return {
                    statuses,
                    logs,
                    selectedService,
                    toggleService,
                    fetchLogs,
                };
            },
        }).mount('#app');
    </script>
</body>
</html>
EOF
}

# Function to setup Node.js application
setup_nodejs_app() {
    npm init -y
    npm install express
    create_nodejs_server
    create_dashboard_html
}

# Function to start services and Node.js application
create_start_script() {
    cat > scripts/start.sh << EOF
#!/bin/bash
service pihole start
service unbound start
service tor start
service privoxy start
wg-quick up wg0
node /app/server.js
EOF
    chmod +x scripts/start.sh
}

# Function to build and run Docker container
build_and_run() {
    docker-compose up --build -d
}

# Main function
main() {
    check_sudo
    install_dependencies
    create_project_structure
    create_base_dockerfile
    create_docker_compose
    create_service_scripts
    setup_nodejs_app
    create_start_script
    build_and_run
    
    echo "Privacy Pi setup complete!"
    echo "Access the dashboard at http://localhost:$DASHBOARD_PORT"
}

# Run the main function
main
