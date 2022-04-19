#!/usr/bin/env bash
# Originally from https://github.com/gvolpe/nix-config

set +x

build_ci_system() {
  nix-channel --add https://nixos.org/channels/nixos-unstable nixos
  cmd="
    nix-build-uncached '<nixpkgs/nixos>' \
      -I nixos-config=configuration.nix \
      -A system
  "
  nix-shell -p nix-build-uncached --run "$cmd"
}

build_ci_system