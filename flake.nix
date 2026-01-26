{
  description = "OpenShift lab environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { pkgs, ... }:
        {
          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              crc
              docker-client
              docker-credential-helpers
              gh
              kubernetes-helm
              kubectl
              kustomize
              kind
              k9s
              openshift
              openssl
              podman
            ];

            CRC = "${pkgs.crc}/bin/crc";
            DOCKER = "${pkgs.docker}/bin/docker";
            GH = "${pkgs.gh}/bin/gh";
            HELM = "${pkgs.kubernetes-helm}/bin/helm";
            KIND = "${pkgs.kind}/bin/kind";
            KUBECTL = "${pkgs.kubectl}/bin/kubectl";
            KUSTOMIZE = "${pkgs.kustomize}/bin/kustomize";
            K9S = "${pkgs.k9s}/bin/k9s";
            OC = "${pkgs.openshift}/bin/oc";
            OPENSSL = "${pkgs.openssl}/bin/openssl";
            PODMAN = "${pkgs.podman}/bin/podman";
          };

          treefmt = {
            programs.nixfmt.enable = true;
          };
        };
    };
}
