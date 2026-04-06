#!/bin/bash
# /usr/local/bin/docker — Buildah-backed Docker shim
#
# Maps supported Docker CLI commands to Buildah equivalents.
# This sandbox supports building and pushing images only — not running containers.

case "${1:-}" in
  build)   shift; exec buildah bud "$@" ;;
  push)    shift; exec buildah push "$@" ;;
  tag)     shift; exec buildah tag "$@" ;;
  images)  shift; exec buildah images "$@" ;;
  login)   shift; exec buildah login "$@" ;;
  rmi)     shift; exec buildah rmi "$@" ;;
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
