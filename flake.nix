{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gourou-src = {
      url = "git://soutade.fr/libgourou.git";
      flake = false;
    };
    updfparser-src = {
      url = "git://soutade.fr/updfparser.git";
      flake = false;
    };
    base64-src = {
      url = "git+https://gist.github.com/f0fd86b6c73063283afe550bc5d77594.git";
      flake = false;
    };
    pugixml-src = {
      url = "github:zeux/pugixml/latest";
      flake = false;
    };
  };

  outputs = flakes:
    flakes.flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ]
      (system:
        let
          version = "1.3.1";
          self = flakes.self.packages.${system};
          nixpkgs = flakes.nixpkgs.legacyPackages.${system}.pkgsStatic;
          nixpkgs-dyn = flakes.nixpkgs.legacyPackages.${system};
          nixpkgs-fmt = flakes.nixpkgs-fmt.defaultPackage.${system};
          gourou-src = flakes.gourou-src;
          updfparser-src = flakes.updfparser-src;
          base64-src = flakes.base64-src;
          pugixml-src = flakes.pugixml-src;
          cxx = "${nixpkgs.stdenv.cc}/bin/${nixpkgs.stdenv.cc.targetPrefix}c++";
          ar = "${nixpkgs.stdenv.cc.bintools.bintools_bin}/bin/${nixpkgs.stdenv.cc.targetPrefix}ar";
          obj-flags = "-O2 -static";
        in
        rec {
          packages.libzip-static = nixpkgs.libzip.overrideAttrs (prev: {
            cmakeFlags = (prev.cmakeFlags or [ ]) ++ [
              "-DBUILD_SHARED_LIBS=OFF"
              "-DBUILD_EXAMPLES=OFF"
              "-DBUILD_DOC=OFF"
              "-DBUILD_TOOLS=OFF"
              "-DBUILD_REGRESS=OFF"
            ];
            outputs = [ "out" ];
          });
          packages.base64 = derivation {
            name = "updfparser";
            inherit system;
            builder = "${nixpkgs.bash}/bin/bash";
            PATH = "${nixpkgs.coreutils}/bin";
            args = [
              "-c"
              ''
                mkdir -p $out/include/base64
                cp ${base64-src}/Base64.h $out/include/base64/Base64.h
              ''
            ];
          };
          packages.updfparser = derivation {
            name = "updfparser";
            inherit system;
            builder = "${nixpkgs.bash}/bin/bash";
            PATH = "${nixpkgs.coreutils}/bin";
            args = [
              "-c"
              ''
                ${cxx} \
                  -c ${updfparser-src}/src/*.cpp \
                  -I ${updfparser-src}/include \
                  ${obj-flags}
                mkdir -p $out/lib
                ${ar} crs $out/lib/libupdfparser.a *.o
              ''
            ];
          };
          packages.gourou = derivation {
            name = "gourou";
            inherit system;
            builder = "${nixpkgs.bash}/bin/bash";
            PATH = "${nixpkgs.coreutils}/bin";
            args = [
              "-c"
              ''
                shopt -s extglob
                ${cxx} \
                  -c \
                  ${gourou-src}/src/!(pugixml).cpp \
                  ${pugixml-src}/src/pugixml.cpp \
                  -I ${self.base64}/include \
                  -I ${gourou-src}/include \
                  -I ${pugixml-src}/src \
                  -I ${updfparser-src}/include \
                  ${obj-flags}
                mkdir -p $out/lib $out/debug
                ${ar} crs $out/lib/libgourou.a *.o
                cp *.o $out/debug
              ''
            ];
          };
          packages.utils-common = derivation {
            name = "utils-common";
            inherit system;
            builder = "${nixpkgs.bash}/bin/bash";
            PATH = "${nixpkgs.coreutils}/bin";
            args = [
              "-c"
              ''
                ${cxx} \
                  -c ${gourou-src}/utils/drmprocessorclientimpl.cpp \
                     ${gourou-src}/utils/utils_common.cpp \
                  -I ${gourou-src}/utils \
                  -I ${gourou-src}/include \
                  -I ${pugixml-src}/src \
                  -I ${nixpkgs.openssl.dev}/include \
                  -I ${nixpkgs.curl.dev}/include \
                  -I ${nixpkgs.zlib.dev}/include \
                  -I ${self.libzip-static}/include \
                  ${obj-flags}
                mkdir -p $out/lib
                ${ar} crs $out/lib/libutils-common.a *.o
              ''
            ];
          };
          packages.knock = derivation {
            name = "knock";
            inherit system;
            builder = "${nixpkgs.bash}/bin/bash";
            PATH = "${nixpkgs.coreutils}/bin";
            args = [
              "-c"
              ''
                mkdir -p $out/bin
                ${cxx} \
                  -o $out/bin/knock \
                  ${./src/knock.cpp} \
                  -D KNOCK_VERSION='"${version}"' \
                  --std=c++17 \
                  -Wl,--as-needed -static \
                  ${self.utils-common}/lib/libutils-common.a \
                  ${self.gourou}/lib/libgourou.a \
                  ${self.updfparser}/lib/libupdfparser.a \
                  -Wl,--start-group \
                  ${self.libzip-static}/lib/libzip.a \
                  ${nixpkgs.libnghttp2}/lib/libnghttp2.a \
                  ${nixpkgs.libidn2.out}/lib/libidn2.a \
                  ${nixpkgs.libunistring}/lib/libunistring.a \
                  ${nixpkgs.libssh2}/lib/libssh2.a \
                  ${nixpkgs.zstd.out}/lib/libzstd.a \
                  ${nixpkgs.zlib}/lib/libz.a \
                  ${nixpkgs.openssl.out}/lib/libcrypto.a \
                  ${nixpkgs.curl.out}/lib/libcurl.a \
                  ${nixpkgs.openssl.out}/lib/libssl.a \
                  -static-libgcc -static-libstdc++ \
                  -Wl,--end-group \
                  -I ${gourou-src}/utils \
                  -I ${gourou-src}/include \
                  -I ${pugixml-src}/src \
                  -I ${nixpkgs.openssl.dev}/include \
                  -I ${nixpkgs.curl.dev}/include \
                  -I ${nixpkgs.zlib.dev}/include \
                  -I ${self.libzip-static}/include
              ''
            ];
          };
          packages.default = self.knock;
          packages.tests = nixpkgs-dyn.stdenv.mkDerivation {
            name = "tests";
            src = ./tests;
            buildInputs = [
              (nixpkgs-dyn.python3.withPackages (p: [
                p.beautifulsoup4
                p.requests
              ]))
            ];
            patchPhase = ''
              substituteInPlace tests.py --replace "./result/bin/knock" "${self.knock}/bin/knock"
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp tests.py $out/bin/tests
              chmod +x $out/bin/tests
            '';
          };
          packages.formatter = nixpkgs.writeShellScriptBin "formatter" ''
            set -x
            ${nixpkgs-dyn.clang-tools}/bin/clang-format -i --verbose ./src/*.cpp
            ${nixpkgs-dyn.nixpkgs-fmt}/bin/nixpkgs-fmt .
            ${nixpkgs-dyn.black}/bin/black ./tests
          '';
        }
      );
}
