{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.bookwyrm;
  redisCfg = config.services.redis.servers;
  env = {
    DEBUG = if cfg.debug then "true" else "false";
    DOMAIN = cfg.domain;
    ALLOWED_HOSTS = lib.concatStringsSep "," cfg.allowedHosts;
    BOOKWYRM_DATABASE_BACKEND = "postgres";
    MEDIA_ROOT = (builtins.toPath cfg.stateDir) + "/images";
    STATIC_ROOT = (builtins.toPath cfg.stateDir) + "/static";
    POSTGRES_HOST = cfg.database.host;
    POSTGRES_USER = cfg.database.user;
    PGPORT = (toString cfg.database.port);
    POSTGRES_DB = cfg.database.database;
    REDIS_ACTIVITY_HOST = cfg.activityRedis.host;
    REDIS_ACTIVITY_PORT = (toString cfg.activityRedis.port);
    REDIS_ACTIVITY_SOCKET = (
      if cfg.activityRedis.unixSocket != null then cfg.activityRedis.unixSocket else ""
    );
    REDIS_BROKER_HOST = cfg.celeryRedis.host;
    REDIS_BROKER_PORT = (toString cfg.celeryRedis.port);
    REDIS_BROKER_SOCKET = (
      if cfg.celeryRedis.unixSocket != null then cfg.celeryRedis.unixSocket else ""
    );
    EMAIL_HOST = cfg.email.host;
    EMAIL_PORT = (toString cfg.email.port);
    EMAIL_HOST_USER = cfg.email.user;
    EMAIL_USE_TLS = if cfg.email.useTLS then "true" else "false";
    EMAIL_USE_SSL = if cfg.email.useSSL then "true" else "false";
  };
  # mapping of env variable → its secret file
  envSecrets = (
    filterAttrs (_: v: v != null) {
      SECRET_KEY = cfg.secretKeyFile;
      POSTGRES_PASSWORD = cfg.database.passwordFile;
      EMAIL_HOST_PASSWORD = cfg.email.passwordFile;
    }
  );

  locallyCreatedRedisUnits =
    optional cfg.activityRedis.createLocally "redis-bookwyrm-activity.service"
    ++ optional cfg.celeryRedis.createLocally "redis-bookwyrm-celery.service";

  loadEnv = (
    pkgs.writeScript "load-bookwyrm-env" ''
      #!/usr/bin/env bash
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg v}") env)}
      ${
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (n: v: ''export ${n}="$(cat ${lib.escapeShellArg v})"'') envSecrets
        )
      } 
    ''
  );
  bookwyrmManageScript =
    bookwyrm:
    (pkgs.writeScriptBin "bookwyrm-manage" ''
      #!/usr/bin/env bash 
      source ${loadEnv}
      exec ${bookwyrm}/bin/bookwyrm-manage "$@"
    '');
in
{
  options.services.bookwyrm = {
    enable = mkEnableOption "bookwyrm";

    package = mkOption {
      type = types.package;
      default = pkgs.bookwyrm;
      description = "Bookwyrm package to use";
    };

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
      example = [
        "unix:/run/bookwyrm-gunicorn.sock"
        "127.0.0.1:12345"
      ];
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
      default = [ "*" ];
      example = [ "bookwyrm.example.com" ];
      description = ''
        List of hosts to allow, checked against the <literal>Host:</literal>
        header. Leave default to accept all hosts.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable debug mode. Debug mode should not be used in
        production, but provides more verbose logging. 
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

      port = mkOption {
        type = types.int;
        default = config.services.postgresql.settings.port;
        description = "Port of the Postgresql server to connect to.";
      };

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

    # TODO: Perhaps support passwords for the redises
    activityRedis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Ensure Redis is running locally and use it.";
      };

      # note that there are assertions to prevent three of these being null
      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Activity Redis host address.";
      };

      port = mkOption {
        type = types.nullOr types.int;
        default = null;
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
        default = null;
        description = "Activity Redis host address.";
      };

      port = mkOption {
        type = types.nullOr types.int;
        default = null;
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
        default = false;
        description = "Whether to use STARTTLS when connecting to the  SMTP server. Exclusive with `useSSL`. Corresponds to Django's `EMAIL_USE_TLS`.";
      };

      useSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to use implicit TLS when connecting with the SMTP server. Exclusive with `useTLS`. Corresponds to Django's `EMAIL_USE_SSL`.";
      };
    };
  };

  config = mkIf cfg.enable {
    warnings =
      (optional (cfg.secretKey != "")
        "config.services.bookwyrm.secretKey will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.secretKeyFile instead."
      )
      ++ (optional (cfg.database.password != "")
        "config.services.bookwyrm.database.password will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.database.passwordFile instead."
      )
      ++ (optional (cfg.email.password != "")
        "config.services.bookwyrm.email.password will be stored in plain text in the Nix store, where it will be world readable. To avoid this, consider using config.services.bookwyrm.email.passwordFile instead."
      );

    assertions = [
      {
        assertion =
          cfg.activityRedis.unixSocket != null
          || (cfg.activityRedis.host != null && cfg.activityRedis.port != null);
        message = "config.services.bookwyrm.activityRedis needs to have either a unixSocket defined, or both a host and a port defined.";
      }
      {
        assertion =
          cfg.celeryRedis.unixSocket != null
          || (cfg.celeryRedis.host != null && cfg.celeryRedis.port != null);
        message = "config.services.bookwyrm.celeryRedis needs to have either a unixSocket defined, or both a host and a port defined.";
      }
      {
        assertion = !(cfg.email.useTLS && cfg.email.useSSL);
        message = "Only one of email.useTLS or email.useSSL can be set to true at a time.";
      }
    ];

    services.bookwyrm.secretKeyFile = (
      mkDefault (
        toString (
          pkgs.writeTextFile {
            name = "bookwyrm-secretkeyfile";
            text = cfg.secretKey;
          }
        )
      )
    );

    services.bookwyrm.database.passwordFile = (
      mkDefault (
        toString (
          pkgs.writeTextFile {
            name = "bookwyrm-secretkeyfile";
            text = cfg.database.password;
          }
        )
      )
    );

    services.bookwyrm.email.passwordFile = (
      mkDefault (
        toString (
          pkgs.writeTextFile {
            name = "bookwyrm-email-passwordfile";
            text = cfg.email.password;
          }
        )
      )
    );

    users.users = mkIf (cfg.user == "bookwyrm") {
      bookwyrm = {
        home = cfg.stateDir;
        group = "bookwyrm";
        useDefaultShell = true;
        isSystemUser = true;
        extraGroups =
          optional cfg.activityRedis.createLocally redisCfg.bookwyrm-activity.user
          ++ optional cfg.celeryRedis.createLocally redisCfg.bookwyrm-celery.user;
      };
    };

    users.groups = mkIf (cfg.group == "bookwyrm") {
      bookwyrm = { };
    };

    services.postgresql = optionalAttrs (cfg.database.createLocally) {
      enable = true;

      ensureDatabases = [ cfg.database.database ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = {
            "DATABASE ${cfg.database.database}" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    services.redis.servers =
      optionalAttrs cfg.activityRedis.createLocally {
        bookwyrm-activity = {
          enable = true;
        };
      }
      // optionalAttrs cfg.celeryRedis.createLocally {
        bookwyrm-celery = {
          enable = true;
        };
      };

    services.bookwyrm.activityRedis.unixSocket = mkIf cfg.activityRedis.createLocally config.services.redis.servers.bookwyrm-activity.unixSocket;
    services.bookwyrm.celeryRedis.unixSocket = mkIf cfg.celeryRedis.createLocally config.services.redis.servers.bookwyrm-celery.unixSocket;

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
      after =
        [
          "network.target"
          "redis.service"
          "postgresql.service"
          "bookwyrm-celery.service"
        ]
        ++ locallyCreatedRedisUnits
        ++ optional cfg.database.createLocally "postgresql.service";
      bindsTo =
        [
          "bookwyrm-celery.service"
        ]
        ++ locallyCreatedRedisUnits
        ++ optional cfg.database.createLocally "postgresql.service";
      wantedBy = [ "bookwyrm.target" ];
      partOf = [ "bookwyrm.target" ];
      environment = env;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        TimeoutStartSec = "15min";
      };

      # TODO: Maybe populate static assets at bookwyrm build time?
      preStart = ''
        ${concatStringsSep "\n" (
          mapAttrsToList (n: v: ''export ${n}="$(cat ${escapeShellArg v})"'') envSecrets
        )}
        ${cfg.package}/bin/bookwyrm-manage migrate --noinput
        ${cfg.package}/bin/bookwyrm-manage collectstatic --noinput --clear
        ${cfg.package}/bin/bookwyrm-manage compile_themes
      '';

      script = ''
        ${concatStringsSep "\n" (
          mapAttrsToList (n: v: ''export ${n}="$(cat ${escapeShellArg v})"'') envSecrets
        )}
        exec ${cfg.package}/bin/gunicorn bookwyrm.wsgi:application \
          ${concatStringsSep " " (map (elem: "--bind ${elem}") cfg.bindTo)} \
          --umask 0007
      '';
    };

    systemd.services.bookwyrm-celery = {
      description = "Celery service for bookwyrm.";
      after = [
        "network.target"
      ] ++ locallyCreatedRedisUnits;
      bindsTo = locallyCreatedRedisUnits;
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
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (n: v: ''export ${n}="$(cat ${escapeShellArg v})"'') envSecrets
        )}
        exec ${cfg.package}/bin/celery -A celerywyrm worker --loglevel=INFO -Q high_priority,medium_priority,low_priority,streams,images,suggested_users,email,connectors,lists,inbox,imports,import_triggered,broadcast,misc
      '';

    };

    systemd.services.bookwyrm-flower = {
      description = "Flower monitoring tool for bookwyrm-celery";
      after = [
        "network.target"
        "redis.service"
        "bookwyrm-celery.service"
      ] ++ locallyCreatedRedisUnits;
      bindsTo = locallyCreatedRedisUnits;
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
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (n: v: ''export ${n}="$(cat ${escapeShellArg v})"'') envSecrets
        )}
        exec ${cfg.package}/bin/celery -A celerywyrm flower \
          ${lib.concatStringsSep " " cfg.flowerArgs}
      '';

    };

    environment.systemPackages = [ (bookwyrmManageScript cfg.package) ];
  };
}
