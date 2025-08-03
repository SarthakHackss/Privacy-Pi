# Privacy Pi

Privacy Pi is an all-in-one privacy solution that sets up a Raspberry Pi (or any compatible system) as a privacy-focused router. It includes Pi-hole for ad-blocking, WireGuard for VPN, Unbound for DNS, and Tor for anonymity.

## Quick Install

To install Privacy Pi, run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/himucodes/privacy-pi/main/setup.sh | sudo bash
```

This command will:
- Install all necessary dependencies (Docker, docker-compose, etc.)
- Set up the Privacy Pi environment
- Build and run the Docker container

## Features

- Pi-hole for network-wide ad blocking
- WireGuard for secure VPN connections
- Unbound for recursive DNS resolution
- Tor for anonymous internet access
- Easy-to-use web dashboard

## Requirements

- Raspberry Pi 4 or newer (recommended), or any system that can run Docker
- Debian-based operating system (Ubuntu, Raspberry Pi OS, etc.)
- Sudo privileges

## Post-Installation

After installation, you can access the dashboard at `http://localhost:3000` (or your Raspberry Pi's IP address).

## Customization

You can customize the setup by modifying the script before running it. The script is modular and easy to extend.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
