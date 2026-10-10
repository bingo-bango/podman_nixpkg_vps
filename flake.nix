{
  description = "Declarative Infrastructure Stack";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ podman-compose rclone gnupg wireguard-tools ];
      };

      apps.${system} = {
        # 'nix run .#up' starts up stack
        up = {
          type = "app";
          program = toString (pkgs.writeShellScript "stack-up" ''
            ${pkgs.podman-compose}/bin/podman-compose up -d
          '');
        };

        # 'nix run .#backup' backs up vw to pcloud
        backup = {
          type = "app";
          program = toString (pkgs.writeShellScript "stack-backup" ''
            ${pkgs.gnupg}/bin/gpg --symmetric --batch --yes --passphrase-file .env.pass ./config/vaultwarden
            ${pkgs.rclone}/bin/rclone copy ./config/vaultwarden.gpg pcloud:/Backups/
          '');
        };
      };
    };
}
