{
  stdenv,
  lib,
  poetry2nix,
  gettext,
  symlinkJoin,
  pkgs,
}:
let
  bookwyrmSource = ./..;
  poetryApp = poetry2nix.mkPoetryApplication rec {
    projectDir = bookwyrmSource;
    src = bookwyrmSource;

    # overrides are related to deps not getting the build systems they need
    # related poetry2nix issues:
    # https://github.com/nix-community/poetry2nix/issues/218
    # https://github.com/nix-community/poetry2nix/issues/568

    overrides =
      (poetry2nix.overrides.withDefaults (
        final: prev: {
          django-sass-processor = prev.django-sass-processor.overridePythonAttrs (prevAttrs: {
            format = "setuptools";
          });

          django-imagekit = prev.django-imagekit.overridePythonAttrs (prevAttrs: {
            format = "setuptools";
          });

          opentelemetry-instrumentation-celery =
            prev.opentelemetry-instrumentation-celery.overridePythonAttrs
              (prevAttrs: {
                format = "pyproject";
                nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.hatchling ];
              });

          opentelemetry-instrumentation-dbapi =
            prev.opentelemetry-instrumentation-dbapi.overridePythonAttrs
              (prevAttrs: {
                format = "pyproject";
                nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.hatchling ];
              });

          opentelemetry-instrumentation-psycopg2 =
            prev.opentelemetry-instrumentation-psycopg2.overridePythonAttrs
              (prevAttrs: {
                format = "pyproject";
                nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.hatchling ];
              });

          bw-file-resubmit = prev.bw-file-resubmit.overridePythonAttrs (prevAttrs: {
            format = "pyproject";
            nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.setuptools-scm ];
          });

          marshmallow = prev.marshmallow.overridePythonAttrs (prevAttrs: {
            format = "pyproject";
            nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.flit-core ];
          });

          django-pgtrigger = prev.django-pgtrigger.overridePythonAttrs (prevAttrs: {
            format = "pyproject";
            nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.poetry-core ];
          });
          aiohappyeyeballs = prev.aiohappyeyeballs.overridePythonAttrs (prevAttrs: {
            format = "pyproject";
            nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.poetry-core ];
          });
          s3-tar = prev.s3-tar.overridePythonAttrs (prevAttrs: {
            format = "setuptools";
          });
          psycopg2 = prev.psycopg2.overridePythonAttrs (prevAttrs: {
            postPatch =
              (prevAttrs.postPatch or "")
              + ''
                substituteInPlace setup.py \
                  --replace-fail "self.pg_config_exe = self.build_ext.pg_config" 'self.pg_config_exe = "${pkgs.libpq.pg_config}/bin/pg_config"'
              '';
          });
        }
      ))
      ++ [
        (final: prev: {
          # using fetchCargoVendor instead of fetchCargoTarball
          # this is an override for a poetry2nix bundled override, so it comes
          # after the withDefaults overrides
          cryptography = prev.cryptography.overridePythonAttrs (prevAttrs: {
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              inherit (prevAttrs) src;
              name = "${prevAttrs.pname}-${prevAttrs.version}";
              sourceRoot = "${prevAttrs.pname}-${prevAttrs.version}/src/rust";
              hash = "sha256-rioZi/lxMHeTLUb8GGRcBP7pCeoBsbhaczTWkCD0ApE=";
            };
          });
        })
      ];

    meta = with lib; {
      homepage = "https://bookwyrm.social/";
      description = "Decentralized social reading and reviewing platform server";
      license = {
        fullName = "The Anti-Capitalist Software License";
        url = "https://anticapitalist.software/";
        free = false;
      };
    };
  };
  updateScripts = stdenv.mkDerivation {
    name = "bookwyrm-update-scripts";
    src = bookwyrmSource;

    dontBuild = true;

    buildInputs = [
      poetryApp.dependencyEnv
    ];

    installPhase = ''
      mkdir -p $out/libexec/bookwyrm

      patchShebangs manage.py

      cp ./manage.py $out/libexec/bookwyrm
    '';
  };
  # The update scripts need to be able to run manage.py under the Bookwyrm
  # environment, but we don't have access to dependencyEnv when building
  # poetryApp. As an ugly workaround, we patch the scripts with the right paths
  # separately, and symlinkJoin them with the original environment.
in
symlinkJoin {
  name = "bookwyrm";
  paths = [
    poetryApp.dependencyEnv
    updateScripts
  ];
}
