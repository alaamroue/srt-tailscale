# srt-tailscale

![GitHub Tag](https://img.shields.io/github/v/tag/alaamroue/srt-tailscale) ![License](https://img.shields.io/github/license/alaamroue/srt-tailscale) ![GitHub Actions Workflow Status - Server](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/docker-publish-server.yml?logo=githubactions&logoColor=white&label=Server%20Build) ![GitHub Actions Workflow Status - Client](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/docker-publish-client.yml?logo=githubactions&logoColor=white&label=Client%20Build) ![GitHub Actions Workflow Status - QA](https://img.shields.io/github/actions/workflow/status/alaamroue/srt-tailscale/verify-workflows.yml?logo=githubactions&logoColor=white&label=Workflow%20Consistency)

![Docker Image Version](https://img.shields.io/docker/v/alaamr/srt-ts-server?sort=semver&logo=docker&logoColor=white&label=DockerHub%3A%20Server)
![Docker Image Version](https://img.shields.io/docker/v/alaamr/srt-ts-client?sort=semver&logo=docker&logoColor=white&label=DockerHub%3A%20Client)


![Shell](https://img.shields.io/badge/Language-Shell-black.svg)
![Docker](https://img.shields.io/badge/Platform-Docker-blue.svg)



Lightweight repo to run SRT (Secure Reliable Transport) endpoints together with Tailscale networking. It contains Docker images, docker-compose configurations and helper scripts to deploy a server and client setup that can stream SRT through a Tailscale mesh.

**Status:** Work in progress — README created/updated to document structure and common workflows.

**Table of contents**
- [Project layout](#project-layout)
- [Prerequisites](#prerequisites)
- [Quick start (development)](#quick-start-development)
- [Developing with WSL](#developing-with-wsl)
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

## Developing with WSL

### WSL setup
Make sure that WLS supports IPv6. In .wslconfig add
```
networkingMode=mirrored
```

## Having a camera device

As having a video feed is part of the development that are two option.

#### Option 1: Attaching camera to WSL (I.e use your own camera)
Run the following in PowerShell (as Administrator):
```ps1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
\\wsl.localhost\<Path-to-Repo>\srt-tailscale\Manage-WSL-Camera.ps1
```

### Option 2: Creating a virtual camera
This requires v4l2loopback, but wsl does not support Linux video devices. Lucky we can add this support to the kernel. This will take between 10-30 mins.

#### 1. Rebuild the kernel in WSL:
```sh
cd ~
git clone https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
# Set wsl config as default config (.config)
cp Microsoft/config-wsl .config

# Add required config
sed -i 's/^CONFIG_MEDIA_SUPPORT=.*/CONFIG_MEDIA_SUPPORT=y/' .config
sed -i 's/^CONFIG_MEDIA_CAMERA_SUPPORT=.*/CONFIG_MEDIA_CAMERA_SUPPORT=y/' .config
sed -i 's/^CONFIG_VIDEO_DEV=.*/CONFIG_VIDEO_DEV=y/' .config

# Build (Will be built to arch/x86/boot/bzImage)
make -j "$(nproc)"

# Copy kernel to Windows so that we can tell WSL2 to use it
cp arch/x86/boot/bzImage /mnt/c/<Your preferred path>/wsl-bzImage
```

#### 2. Tell windows to use our built kernel when running WSL
This is done but editing the .wslconfig (Normally in %UserProfile%\.wslconfig)
```bash
# Add this line to .wslconfig
# kernel=C:\\<Your preferred path>\\wsl-bzImage
# Example
kernel=C:\\Users\\alaa\\wsl-bzImage
```

#### 3. Restart WSL
```bash
wsl --shutdown
wsl
```

#### 4. Build v4l2loopback
```sh
cd ~
git clone https://github.com/umlaeute/v4l2loopback.git
cd v4l2loopback

# Create Makefile.wsl
cat << 'EOF' > Makefile.wsl
obj-m := v4l2loopback.o

KDIR := $(HOME)/WSL2-Linux-Kernel

all:
        make -C $(KDIR) M=$(PWD) modules

clean:
        make -C $(KDIR) M=$(PWD) clean
EOF

# Build
make -f Makefile.wsl

# Copy built libs
sudo mkdir -p /lib/modules/$(uname -r)/extra
sudo cp v4l2loopback.ko /lib/modules/$(uname -r)/extra/
sudo depmod -a
```

#### 5. Create devices
Quick demo on how to create devices and simulate a camera.

Add devices 
```sh
# Exmaple for 3 devices at /dev/video0, /dev/video1, /dev/video2
sudo modprobe v4l2loopback video_nr=0,1,2 card_label="FakeCam" exclusive_caps=1
```

Remove devices:
```sh
sudo modprobe -r v4l2loopback
```

Feed a feed to /dev/video0
```sh
ffmpeg -f lavfi -i testsrc=size=1280x720:rate=30 -f v4l2 -vcodec rawvideo /dev/video0
```

View the feed
```sh
ffplay /dev/video0
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
