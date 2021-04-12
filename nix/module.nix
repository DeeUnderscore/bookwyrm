{ config, lib, pkgs, ... }: 

with lib; 

let 
  pinnedPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/949d727aaf327384530ebf5a23dd138a7f93ce29.tar.gz";
  }) { };
  bookwyrm = (pinnedPkgs.callPackage ./default.nix { });
  cfg = config.services.bookwyrm;
  celeryRedisPath = if cfg.celeryRedis.unixSocket != null then
      "redis+socket://${cfg.celeryRedis.unixSocket}?virtual_host=0"
    else
      "redis://${cfg.celeryRedis.host}:${toString cfg.celeryRedis.port}/0";
  env = {
    DEBUG = "true";
    DOMAIN = cfg.domain;
    BOOKWYRM_DATABASE_BACKEND = "postgres";
    MEDIA_ROOT = (builtins.toPath cfg.stateDir) + "/images";
    STATIC_ROOT = (builtins.toPath cfg.stateDir) + "/static";
    POSTGRES_HOST = cfg.database.host;
    POSTGRES_USER = cfg.database.user;
    POSTGRES_DB = cfg.database.database;
    REDIS_ACTIVITY_HOST = cfg.activityRedis.host;
    REDIS_ACTIVITY_PORT = (toString cfg.activityRedis.port);
    REDIS_ACTIVITY_SOCKET = (if cfg.activityRedis.unixSocket != null then cfg.activityRedis.unixSocket else "");
    CELERY_BROKER  = celeryRedisPath;
    CELERY_RESULT_BACKEND = celeryRedisPath;
    EMAIL_HOST = cfg.email.host;
    EMAIL_PORT = (toString cfg.email.port);
    EMAIL_HOST_USER = cfg.email.user;
    EMAIL_USE_TLS = if cfg.email.useTLS then "true" else "false";
    OL_URL = "https://openlibrary.org";
  };
  # mapping of env variable → its secret file 
  envSecrets = (filterAttrs (_: v: v != null) {
    SECRET_KEY = cfg.secretKeyFile;
    POSTGRES_PASSWORD = cfg.database.passwordFile;
    EMAIL_HOST_PASSWORD = cfg.email.passwordFile;
  });

  redisCreateLocally = cfg.celeryRedis.createLocally || cfg.activityRedis.createLocally;

  loadEnv = (pkgs.writeScript "load-bookwyrm-env" ''
    #!/usr/bin/env bash
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}='${v}'") env)}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: ''export ${n}="$(cat '${v}')"'')  envSecrets)} 
  '');
  bookwyrmManageScript = (pkgs.writeScriptBin "bookwyrm-manage" ''
    #!/usr/bin/env bash 
    source ${loadEnv}
    exec ${bookwyrm}/bin/python ${bookwyrm}/manage.py "$@"
  '');
in
{
  options.services.bookwyrm = {
    enable = mkEnableOption "bookwyrm";

    user = mkOption { 
      type = types.str;
      default = "bookwyrm";
      description = "User to run bookwyrm as.";
    };

    group = mkOption {
      type = types.str;
      default = "bookwyrm";
      description = "Group to run bookwyrm as.";
    };

    stateDir = mkOption { 
      type = types.str;
      default = "/var/lib/bookwyrm";
      description = "Data directory for Bookwyrm.";
    };

    bindTo = mkOption {
      type = types.listOf types.str;
      default = [ "unix:/run/bookwyrm/bookwyrm.sock" ];
      example = [ "unix:/run/bookwyrm-gunicorn.sock" "127.0.0.1:12345" ];
      description = "List of sockets for Gunicorn to bind to"; 
    };

    flowerArgs = mkOption {
      type = types.listOf types.str;
      default = [ "--unix_socket=/run/bookwyrm/bookwyrm-flower.sock" ];
      description = "Arguments to pass to Flower (Celery management frontend).";
    };

    secretKey = mkOption {
      type = types.str;
      default = "";
      description = ''
        Secret key, for Django to use for cryptographic signing. This is stored
        in plain text in the Nix store. Consider using
        <option>secretKeyFile</option> instead.
      '';
    };

    secretKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/bookwyrm-key";
      description = ''
        A file containing the secret key, corrsponding to 
        <option>secretKey</option>.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "bookwyrm.example.com";
      description = ''
        Domain under which Bookwyrm is running;
      '';
    };

    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of hosts to allow, checked against the <literal>Host:</literal>
        header. Leave empty to accept all hosts.
      '';
    };

    database = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Create the database and user locally.";
      };

      host = mkOption {
        type = types.str; 
        default = "";
        description = ''
          Postgresql host address. Set to empty string <literal>""</literal> to
          use unix sockets. 
          '';
      };

      # this is currently hardcoded

      # port = mkOption {
      #  type = types.int;
      #  default = config.services.postgresql.port;
      #  description = "Port of the Postgresql server to connect to.";
      #};

      database = mkOption {
        type = types.str;
        default = "bookwyrm";
        description = "Name of the database to use.";
      };

      user = mkOption {
        type = types.str;
        default = "bookwyrm";
        description = "Database role to use for bookwyrm";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = ''
          Password to use for database authentication. This will be stored in the
          Nix store; consider using <option>database.passwordFile</option> instead.
        '';
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/bookwyrm-db-password";
        description = ''
          A file containing the database password corresponding to 
          <option>database.password</option>.
        '';
      };
    };

    activityRedis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Ensure Redis is running locally and use it.";
      };

      # note that there are assertions to prevent three of these being null
      host = mkOption {
        type = types.nullOr types.str; 
        default = "127.0.0.1";
        description = "Activity Redis host address.";
      }; 

      port = mkOption {
        type = types.nullOr types.int;
        default = config.services.redis.port;
        description = "Activity Redis port.";
      };

      unixSocket = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/redis/redis.sock";
        description = ''
          Unix socket to connect to for activity Redis. When set, the host and
          port option will be ignored.
        '';
      };
    };

    celeryRedis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Ensure Redis is running locally and use it.";
      };

      # note that there are assertions to prevent all three of these being null
      host = mkOption {
        type = types.nullOr types.str; 
        default = "127.0.0.1";
        description = "Activity Redis host address.";
      }; 

      port = mkOption {
        type = types.nullOr types.int;
        default = config.services.redis.port;
        description = "Activity Redis port.";
      };

      unixSocket = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/redis/redis.sock";
        description = ''
          Unix socket to connect to for celery Redis. When set, the host and
          port option will be ignored.
        '';
      };
    };

    email = {
      host = mkOption {
        type = types.str;
        example = "smtp.example.com";
        description = "SMTP server host address.";
      };

      port = mkOption {
        type = types.int;
        example = "465";
        description = "SMTP server port.";
      };

      user = mkOption {
        type = types.str;
        default = "";
        description = "Username to use for SMTP authentication.";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = ''
          Password to use for SMTP authentication. This will be stored in the
          Nix store; consider using <option>email.passwordFile</option> instead.
        '';
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/bookwyrm-smtp-password";
        description = ''
          A file containing the SMTP password corresponding to 
          <option>email.password</option>.
        '';
      };

      useTLS = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use TLS for communication with the SMTP server.";
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = 
      (optional (cfg.secretKey != "") "config.services.bookwyrm.secretKey will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.secretKeyFile instead.")
      ++ (optional (cfg.database.password != "" && cfg.database.passwordFile == null) "config.services.bookwyrm.database.password will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.database.passwordFile instead.")
      ++ (optional (cfg.email.password != "") "config.services.bookwyrm.email.password will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.email.passwordFile instead.");

    assertions = [
      { assertion = cfg.activityRedis.unixSocket != null || (cfg.activityRedis.host != null && cfg.activityRedis.port != null);
        message = "config.services.bookwyrm.activityRedis needs to have either a unixSocket defined, or both a host and a port defined.";
      }
      { assertion = cfg.celeryRedis.unixSocket != null || (cfg.celeryRedis.host != null && cfg.celeryRedis.port != null);
        message = "config.services.bookwyrm.celeryRedis needs to have either a unixSocket defined, or both a host and a port defined.";
      }
    ];

    services.bookwyrm.secretKeyFile = 
      (mkDefault (toString (pkgs.writeTextFile {
        name = "bookwyrm-secretkeyfile";
        text = cfg.secretKey;
      })));

    services.bookwyrm.database.passwordFile = 
      if cfg.database.password != "" && cfg.database.passwordFile == null then
        (toString (pkgs.writeTextFile {
          name = "bookwyrm-secretkeyfile";
          text = cfg.database.password;
        }))
      else null;

    services.bookwyrm.email.passwordFile = 
      (mkDefault (toString (pkgs.writeTextFile {
        name = "bookwyrm-email-passwordfile";
        text = cfg.email.password;
      })));

    users.users = mkIf (cfg.user == "bookwyrm") {
      bookwyrm = {
        home = cfg.stateDir;
        group = "bookwyrm";
        useDefaultShell = true;
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "bookwyrm") {
      bookwyrm = { };  
    };

    services.postgresql = optionalAttrs (cfg.database.createLocally) {
      enable = true;

      ensureDatabases = [ cfg.database.database ];
      ensureUsers = [
        { name = cfg.database.user;
          ensurePermissions = { "DATABASE ${cfg.database.database}" = "ALL PRIVILEGES"; }; 
        }
      ];
    };

    services.redis = optionalAttrs (cfg.activityRedis.createLocally || cfg.celeryRedis.createLocally) {
      enable = true;
    };

    systemd.targets.bookwyrm = {
      description = "Target for all bookwyrm services";
      wantedBy = [ "multi-user.target" ];
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d /run/bookwyrm 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/images' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/static' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.bookwyrm = {
      description = "Bookwyrm reading and reviewing social network server";
      after = [ 
        "network.target"
        "redis.service"
        "postgresql.service"
        "bookwyrm-celery.service"
      ] ++ optional redisCreateLocally "redis.service"
        ++ optional cfg.database.createLocally "postgresql.service"; 
      bindsTo = [
        "bookwyrm-celery.service"
      ] ++ optional redisCreateLocally "redis.service"
        ++ optional cfg.database.createLocally "postgresql.service";
      wantedBy = [ "bookwyrm.target" ];
      partOf = [ "bookwyrm.target" ];
      environment = env;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
      };

      preStart = ''
        ${concatStringsSep "\n" (mapAttrsToList (n: v: ''export ${n}="$(cat '${v}')"'') envSecrets)}
        ${bookwyrm}/bin/python ${bookwyrm}/manage.py migrate --noinput
        ${bookwyrm}/bin/python ${bookwyrm}/manage.py collectstatic --noinput
      '';

      script = ''
        ${concatStringsSep "\n" (mapAttrsToList (n: v: ''export ${n}="$(cat '${v}')"'') envSecrets)}
        exec ${bookwyrm}/bin/gunicorn bookwyrm.wsgi:application \
          ${concatStringsSep " " (map (elem: "--bind ${elem}") cfg.bindTo)}
          --umask 0660
      '';
    };

    systemd.services.bookwyrm-celery = {
      description = "Celery service for bookwyrm.";
      after = [ 
        "network.target"
      ] ++ optional redisCreateLocally "redis.service";
      bindsTo = optionals redisCreateLocally [
        "redis.service"
      ];
      wantedBy = [ "bookwyrm.target" ];
      partOf = [ "bookwyrm.target" ];
      environment = env;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
      };

      script = ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: ''export ${n}="$(cat '${v}')"'') envSecrets)}
        exec ${bookwyrm}/bin/celery worker -A=celerywyrm --loglevel=INFO
      '';

    };

    systemd.services.bookwyrm-flower = {
      description = "Flower monitoring tool for bookwyrm-celery";
      after = [ 
        "network.target"
        "redis.service"
        "bookwyrm-celery.service"
      ] ++ optional redisCreateLocally "redis.service";
      bindsTo = optionals redisCreateLocally [
        "redis.service"
      ];
      wantedBy = [ "bookwyrm.target" ];
      partOf = [ "bookwyrm.target" ];
      environment = {
        CELERY_BROKER_URL = env.CELERY_BROKER;  
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
      };

      script = ''
        ${bookwyrm}/bin/flower \
          ${lib.concatStringsSep " " cfg.flowerArgs}
      '';

    };
    
    environment.systemPackages = [ bookwyrmManageScript ];
  };
}