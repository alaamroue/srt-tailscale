# srt-tailscale

![GitHub Tag](https://img.shields.io/github/v/tag/alaamroue/srt-tailscale) ![License](https://img.shields.io/github/license/alaamroue/srt-tailscale) ![GitHub Actions Workflow Status - Server](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/docker-publish-server.yml?logo=githubactions&logoColor=white&label=Server%20Build) ![GitHub Actions Workflow Status - Client](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/docker-publish-client.yml?logo=githubactions&logoColor=white&label=Client%20Build) ![GitHub Actions Workflow Status - QA](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/verify-workflows.yml?logo=githubactions&logoColor=white&label=Workflow%20Consistency)



![Shell](https://img.shields.io/badge/Language-Shell-black.svg)
![Docker](https://img.shields.io/badge/Platform-Docker-blue.svg)



Lightweight repo to run SRT (Secure Reliable Transport) endpoints together with Tailscale networking. It contains Docker images, docker-compose configurations and helper scripts to deploy a server and client setup that can stream SRT through a Tailscale mesh.

**Status:** Work in progress — README created/updated to document structure and common workflows.

**Table of contents**
- [Project layout](#project-layout)
- [Prerequisites](#prerequisites)
- [Quick start (development)](#quick-start-development)
- [Deploy to a VPS / production](#deploy-to-a-vps--production)
- [Scripts and utilities](#scripts-and-utilities)
- [License](#license)

## Project layout

Top-level (important folders/files):

- `client/` — Dockerfile and client-side code/config for the SRT client image.
- `server/` — Dockerfile and server-side code/config for the SRT server image.
- `infra/` — `docker-compose` files for client and server, for both dev and prod variants.
- `scripts/` — Convenience scripts for deploy, reset, prune and shutdown operations.
- `bump-version.sh`, `vpsSetup.sh` — utility scripts.

Open the folders to see specific `Dockerfile` and `docker-compose` files used to build and run the images.

## Prerequisites

- Docker and Docker Compose installed on the machine(s) that will run client/server.
- A Tailscale account and an auth key for unattended machines if you plan to run on remote VPSes

## Quick start (development)

These steps run the server and a client locally using the development compose files.

```bash
git clone https://github.com/alaamroue/srt-tailscale.git
cd srt-tailscale
./scripts/deploy-server.sh dev
./scripts/deploy-client.sh dev
```

## Deploy to a VPS / production

These steps run the server and a client locally using the prod compose files.

### On the server:
```bash
export TS_AUTHKEY_SERVER=KEY_GOES_HERE
git clone https://github.com/alaamroue/srt-tailscale.git
cd srt-tailscale
./scripts/deploy-server.sh
```

### On the client
```bash
export TS_AUTHKEY_CLIENT=KEY_GOES_HERE
git clone https://github.com/alaamroue/srt-tailscale.git
cd srt-tailscale
./scripts/deploy-client.sh
```

## Scripts and utilities

- `scripts/deploy-server.sh` — deploy server components (wraps docker-compose operations). 
- `scripts/deploy-client.sh` — deploy client components (wraps docker-compose operations). 
- `scripts/complete-reset.sh` — convenience script to remove containers, volumes and networks for a clean state.
- `scripts/prune-docker.sh` — DONT_USE. prune unused images/containers (use with caution).
- `scripts/shutdown-server.sh`, `scripts/shutdown-client.sh` — bring down services cleanly.
- `bump-version.sh` — helper to bump image/client versions (project-specific workflow).
- `vpsSetup.sh` — Guide on VPS setup steps

Always open each script and inspect it; do not run unreviewed scripts on production systems.

## License

See the `LICENSE` file in the repo for licensing details.
