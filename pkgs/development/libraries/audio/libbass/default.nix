{ stdenv, unzip, fetchurl }:

let
  version = "24";

  allBass = {
    bass = {
      h = "bass.h";
      so = {
        i686_linux = "libbass.so";
        x86_64-linux = "x64/libbass.so";
      };
      urlpath = "bass${version}-linux.zip";
      sha256 = "0alxx7knkvzwwifqrmzavafwq53flja7s1ckaabk6p2ir2f0j5cp";
    };

    bass_fx = {
      h = "C/bass_fx.h";
      so = {
        i686_linux = "libbass_fx.so";
        x86_64-linux = "x64/libbass_fx.so";
      };
      urlpath = "z/0/bass_fx${version}-linux.zip";
      sha256 = "0j1cbq88j3vnqf2bibcqnfhciz904w48ldgycyh9d8954hwyg22m";
    };
  };

  dropBass = name: bass: stdenv.mkDerivation {
    name = "lib${name}-${version}";

    src = fetchurl {
      url = "https://www.un4seen.com/files/${bass.urlpath}";
      inherit (bass) sha256;
    };
    unpackCmd = ''
      mkdir out
      ${unzip}/bin/unzip $curSrc -d out
    '';

    lpropagatedBuildInputs = [ unzip ];
    dontBuild = true;
    installPhase =
      let so =
            if bass.so ? ${stdenv.hostPlatform.system} then bass.so.${stdenv.hostPlatform.system}
            else throw "${name} not packaged for ${stdenv.hostPlatform.system} (yet).";
      in ''
        mkdir -p $out/{lib,include}
        install -m644 -t $out/lib/ ${so}
        install -m644 -t $out/include/ ${bass.h}
      '';

    meta = with stdenv.lib; {
      description = "Shareware audio library";
      homepage = https://www.un4seen.com/;
      license = licenses.unfreeRedistributable;
      platforms = builtins.attrNames bass.so;
    };
  };

in stdenv.lib.mapAttrs dropBass allBass
