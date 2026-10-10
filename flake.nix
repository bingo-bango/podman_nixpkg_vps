{
  description = "Self-contained declarative stack for Traefik & Vaultwarden";

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
        buildInputs = with pkgs; [
          podman
          podman-compose
          rclone
          gnupg
          jq
        ];

        shellHook = ''
          export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
        '';
      };

      apps.${system} = {
        # Launch container stack with environment variables loaded
        up = {
          type = "app";
          program = toString (pkgs.writeShellScript "stack-up" ''
            set -euo pipefail
            if [ -f .env ]; then
              set -a
              source .env
              set +a
            fi
            ${pkgs.podman-compose}/bin/podman-compose up -d
          '');
        };

        # Stop container stack
        down = {
          type = "app";
          program = toString (pkgs.writeShellScript "stack-down" ''
            set -euo pipefail
            ${pkgs.podman-compose}/bin/podman-compose down
          '');
        };

# Safe Backup (Stop container -> Tar -> Start container)
backup = {
  type = "app";
  program = toString (pkgs.writeShellScript "stack-backup" ''
    set -euo pipefail
    if [ -f .env ]; then set -a; source .env; set +a; fi

    TIMESTAMP=$(${pkgs.coreutils}/bin/date +"%Y%m%d_%H%M%S")
    ARCHIVE="/tmp/vaultwarden_$TIMESTAMP.tar.gz.gpg"

    echo "Stopping Vaultwarden container for consistent snapshot..."
    ${pkgs.podman}/bin/podman stop vaultwarden || true

    echo "Compressing and encrypting Vaultwarden data..."
    tar -czf - -C ./config/vaultwarden . | ${pkgs.gnupg}/bin/gpg --symmetric --batch --yes \
      --passphrase "''${BACKUP_PASSPHRASE}" \
      -o "$ARCHIVE"

    echo "Restarting Vaultwarden..."
    ${pkgs.podman}/bin/podman start vaultwarden || true

    echo "Uploading encrypted backup to pCloud..."
    ${pkgs.rclone}/bin/rclone copy "$ARCHIVE" pcloud:/Backups/Vaultwarden/

    rm -f "$ARCHIVE"
    echo "Backup completed successfully!"
  '');
};

# Safe Restore (Stop stack -> Decrypt & Extract -> Start stack)
restore = {
  type = "app";
  program = toString (pkgs.writeShellScript "stack-restore" ''
    set -euo pipefail
    if [ -f .env ]; then set -a; source .env; set +a; fi

    TEMP_ARCHIVE="/tmp/latest_restore.tar.gz.gpg"

    echo "Stopping container stack before restore..."
    ${pkgs.podman-compose}/bin/podman-compose down || true

    echo "Fetching latest backup listing from pCloud..."
    LATEST_FILE=$(${pkgs.rclone}/bin/rclone lsf pcloud:/Backups/Vaultwarden/ --sort name | tail -n 1)

    if [ -z "$LATEST_FILE" ]; then
      echo "Error: No backups found in pCloud!"
      exit 1
    fi

    echo "Downloading $LATEST_FILE..."
    ${pkgs.rclone}/bin/rclone copy "pcloud:/Backups/Vaultwarden/$LATEST_FILE" /tmp/ -P
    mv "/tmp/$LATEST_FILE" "$TEMP_ARCHIVE"

    echo "Decrypting and restoring to ./config/vaultwarden..."
    mkdir -p ./config/vaultwarden
    ${pkgs.gnupg}/bin/gpg --decrypt --batch --yes \
      --passphrase "''${BACKUP_PASSPHRASE}" "$TEMP_ARCHIVE" | tar -xzf - -C ./config/vaultwarden

    rm -f "$TEMP_ARCHIVE"
    echo "Restore completed successfully! You can now run 'nix run .#up'."
  '');
};

  

        
        };
      };
    };
}
