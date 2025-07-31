{ pkgs ? import <nixos-unstable> { } }:
pkgs.mkShell { packages = with pkgs; [ go gopls gotools nil ]; }
