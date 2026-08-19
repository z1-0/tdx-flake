# TDX Financial Terminal

A Nix flake that packages the TDX Financial Terminal for NixOS from the UOS `.deb` release.

Supports `x86_64-linux` and `aarch64-linux`.

## Install

Run directly without installing:

```bash
nix run github:z1-0/tdx-flake
```

Or install it permanently:

```bash
nix profile install github:z1-0/tdx-flake
```

### As a flake input

Add to your flake:

```nix
inputs.tdx.url = "github:z1-0/tdx-flake";
```

**NixOS system-wide**

```nix
environment.systemPackages = [
  inputs.tdx.packages.${pkgs.system}.default
];
```

**Home Manager**

```nix
home.packages = [
  inputs.tdx.packages.${pkgs.system}.default
];
```
