#!/bin/bash
# /usr/local/bin/docker — Buildah-backed Docker shim
#
# Maps supported Docker CLI commands to Buildah equivalents.
# This sandbox supports building and pushing images only — not running containers.
#
# Uses sudo because rootless Buildah requires user namespace support
# (newuidmap/newgidmap) which is unavailable inside containers.

case "${1:-}" in
  build)   shift; exec sudo buildah bud --isolation chroot "$@" ;;
  push)    shift; exec sudo buildah push "$@" ;;
  tag)     shift; exec sudo buildah tag "$@" ;;
  images)  shift; exec sudo buildah images "$@" ;;
  login)   shift; exec sudo buildah login "$@" ;;
  rmi)     shift; exec sudo buildah rmi "$@" ;;
  "")
    echo "docker: Buildah-backed shim (build and push only)"
    echo ""
    echo "Supported commands: build, push, tag, images, login, rmi"
    echo "Unsupported: run, compose, ps, exec, and other runtime commands."
    exit 0
    ;;
  *)
    echo "Unsupported: 'docker $1' is not available in this sandbox."
    echo "Supported commands: build, push, tag, images, login, rmi"
    exit 1
    ;;
esac
