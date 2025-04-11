#!/bin/bash

# 2>/dev/null        ignore errors
# podman pod start vpnDownloadPod  # Start the pod
podman pod stop vpnDownloadPod 2>/dev/null  # stops the pod
podman pod rm vpnDownloadPod 2>/dev/null  # removes the pod

podman pod stop arrPod 2>/dev/null
podman pod rm arrPod 2>/dev/null

podman stop plex 2>/dev/null
podman rm plex 2>/dev/null
