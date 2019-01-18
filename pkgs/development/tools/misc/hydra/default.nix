{ stdenv, nix, perlPackages, buildEnv, releaseTools, fetchFromGitHub
, makeWrapper, autoconf, automake, libtool, unzip, pkgconfig, sqlite, libpqxx
, gitAndTools, mercurial, darcs, subversion, bazaar, openssl, bzip2, libxslt
, guile, perl, postgresql, nukeReferences, git, boehmgc
, docbook_xsl, openssh, gnused, coreutils, findutils, gzip, lzma, gnutar
, rpm, dpkg, cdrkit, pixz, lib, fetchpatch, boost, autoreconfHook
}:

with stdenv;

let
  isGreaterNix20 = with lib.versions;
    let
      inherit (nix) version;
      inherit (lib) toInt;
    in major version == "2" && toInt (minor version) >= 1 || toInt (major version) > 2;

  perlDeps = buildEnv {
    name = "hydra-perl-deps";
    paths = with perlPackages;
      [ ModulePluggable
        CatalystActionREST
        CatalystAuthenticationStoreDBIxClass
        CatalystDevel
        CatalystDispatchTypeRegex
        CatalystPluginAccessLog
        CatalystPluginAuthorizationRoles
        CatalystPluginCaptcha
        CatalystPluginSessionStateCookie
        CatalystPluginSessionStoreFastMmap
        CatalystPluginStackTrace
        CatalystRuntime
        CatalystTraitForRequestProxyBase
        CatalystViewDownload
        CatalystViewJSON
        CatalystViewTT
        CatalystXRoleApplicator
        CatalystXScriptServerStarman
        CryptRandPasswd
        DBDPg
        DBDSQLite
        DataDump
        DateTime
        DigestSHA1
        EmailMIME
        EmailSender
        FileSlurp
        IOCompress
        IPCRun
        JSON
        JSONAny
        JSONXS
        LWP
        LWPProtocolHttps
        NetAmazonS3
        NetStatsd
        PadWalker
        Readonly
        SQLSplitStatement
        SetScalar
        Starman
        SysHostnameLong
        TextDiff
        TextTable
        XMLSimple
        nix
        nix.perl-bindings
        git
        boehmgc
      ];
  };
in releaseTools.nixBuild rec {
  name = "hydra-${version}";
  version = "2018-08-07";

  inherit stdenv;

  src = fetchFromGitHub {
    owner = "NixOS";
    repo = "hydra";
    rev = "4dca8fe14d3f782bdf927f37efce722acefffff3";
    sha256 = "1yas4psmvfp7lhcp81ia2sy93b78j9hiw9a6n3q2m1a616hwpm25";
  };

  buildInputs =
    [ makeWrapper autoconf automake libtool unzip nukeReferences pkgconfig sqlite libpqxx
      gitAndTools.topGit mercurial darcs subversion bazaar openssl bzip2 libxslt
      guile # optional, for Guile + Guix support
      perlDeps perl nix
      postgresql # for running the tests
    ] ++ lib.optionals isGreaterNix20 [ boost ];

  hydraPath = lib.makeBinPath (
    [ sqlite subversion openssh nix coreutils findutils pixz
      gzip bzip2 lzma gnutar unzip git gitAndTools.topGit mercurial darcs gnused bazaar
    ] ++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ] );

  nativeBuildInputs = [ autoreconfHook ];

  # adds a patch which ensures compatibility with the API of Nix 2.0.
  # it has been reverted in https://github.com/NixOS/hydra/commit/162d671c48a418bd10a8a171ca36787ef3695a44,
  # for Nix 2.1/unstable compatibility. Reapplying helps if Nix 2.0 is used to keep the build functional.
  patches = lib.optionals (!isGreaterNix20) [
    (fetchpatch {
      url = "https://github.com/NixOS/hydra/commit/08de434bdd0b0a22abc2081be6064a6c846d3920.patch";
      sha256 = "0kz77njp5ynn9l81g3q8zrryvnsr06nk3iw0a60187wxqzf5fmf8";
    })
  ];

  configureFlags = [ "--with-docbook-xsl=${docbook_xsl}/xml/xsl/docbook" ];

  shellHook = ''
    PATH=$(pwd)/src/script:$(pwd)/src/hydra-eval-jobs:$(pwd)/src/hydra-queue-runner:$(pwd)/src/hydra-evaluator:$PATH
    PERL5LIB=$(pwd)/src/lib:$PERL5LIB;
  '';

  enableParallelBuilding = true;

  preCheck = ''
    patchShebangs .
    export LOGNAME=''${LOGNAME:-foo}
  '';

  postInstall = ''
    mkdir -p $out/nix-support
    for i in $out/bin/*; do
        read -n 4 chars < $i
        if [[ $chars =~ ELF ]]; then continue; fi
        wrapProgram $i \
            --prefix PERL5LIB ':' $out/libexec/hydra/lib:$PERL5LIB \
            --prefix PATH ':' $out/bin:$hydraPath \
            --set HYDRA_RELEASE ${version} \
            --set HYDRA_HOME $out/libexec/hydra \
            --set NIX_RELEASE ${nix.name or "unknown"}
    done
  ''; # */

  dontStrip = true;

  passthru.perlDeps = perlDeps;

  meta = with stdenv.lib; {
    description = "Nix-based continuous build system";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ma27 ];
  };
}
