{ pkgs }:
final: prev: {
  hiredis = prev.hiredis.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  rjsmin = prev.rjsmin.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  pyyaml = prev.pyyaml.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  cffi = prev.cffi.overrideAttrs (prevAttrs: {
    buildInputs = (prevAttrs.buildInputs or [ ]) ++ [
      pkgs.libffi
    ];
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ [ pkgs.pkg-config ]
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  python-crontab = prev.python-crontab.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  rcssmin = prev.rcssmin.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  grpcio = prev.grpcio.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
  s3-tar = prev.s3-tar.overrideAttrs (prevAttrs: {
    nativeBuildInputs =
      (prevAttrs.nativeBuildInputs or [ ])
      ++ (final.resolveBuildSystem {
        setuptools = [ ];
        wheel = [ ];
      });
  });
}
