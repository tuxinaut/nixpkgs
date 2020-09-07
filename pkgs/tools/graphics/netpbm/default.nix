{ lib
, stdenv
, fetchsvn
, pkg-config
, libjpeg
, libpng
, jbigkit
, flex
, zlib
, perl
, libxml2
, makeWrapper
, libtiff
, enableX11 ? false
, libX11
, buildPackages
}:

stdenv.mkDerivation {
  # Determine version and revision from:
  # https://sourceforge.net/p/netpbm/code/HEAD/log/?path=/advanced
  name = "netpbm-10.91.3";

  outputs = [ "bin" "out" "dev" ];

  src = fetchsvn {
    url = "https://svn.code.sf.net/p/netpbm/code/advanced";
    rev = "3940";
    sha256 = "DLpby9vZ1fZd1Cb5GbNcfKWkWh27jwoog5W+p2FM7IM=";
  };

  nativeBuildInputs = [
    pkg-config
    flex
    makeWrapper
  ];

  buildInputs = [
    zlib
    perl
    libpng
    libjpeg
    libxml2
    libtiff
    jbigkit
  ] ++ lib.optional enableX11 libX11;


  strictDeps = true;

  enableParallelBuilding = true;

  # Environment variables
  STRIPPROG = "${stdenv.lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}strip";

  postPatch = ''
    # Install libnetpbm.so symlink to correct destination
    substituteInPlace lib/Makefile \
      --replace '/sharedlink' '/lib'

    # TODO: move to config.mk in 10.91.4
    substituteInPlace GNUmakefile \
        --replace 'pkg-config' '${buildPackages.pkgconfig}/bin/${buildPackages.pkgconfig.targetPrefix}pkg-config'
  '';

  configurePhase = ''
    runHook preConfigure

    cp config.mk.in config.mk

    # Disable building static library
    echo "STATICLIB_TOO = N" >> config.mk

    # Enable cross-compilation
    echo 'AR = ${stdenv.lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ar' >> config.mk
    echo 'CC = ${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc' >> config.mk
    echo 'CC_FOR_BUILD = ${buildPackages.stdenv.cc}/bin/${buildPackages.stdenv.cc.targetPrefix}cc' >> config.mk
    echo 'LD_FOR_BUILD = $(CC_FOR_BUILD)' >> config.mk
    echo 'RANLIB = ${stdenv.lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ranlib' >> config.mk

    # Use libraries from Nixpkgs
    echo "TIFFLIB = libtiff.so" >> config.mk
    echo "TIFFLIB_NEEDS_JPEG = N" >> config.mk
    echo "TIFFLIB_NEEDS_Z = N" >> config.mk
    echo "JPEGLIB = libjpeg.so" >> config.mk
    echo "JBIGLIB = libjbig.a" >> config.mk
    # Insecure
    echo "JASPERLIB = NONE" >> config.mk

    # Fix path to rgb.txt
    echo "RGB_DB_PATH = $out/share/netpbm/misc/rgb.txt" >> config.mk
  '' + stdenv.lib.optionalString stdenv.isDarwin ''
    echo "LDSHLIB=-dynamiclib -install_name $out/lib/libnetpbm.\$(MAJ).dylib" >> config.mk
    echo "NETPBMLIBTYPE = dylib" >> config.mk
    echo "NETPBMLIBSUFFIX = dylib" >> config.mk
  '' + ''
    runHook postConfigure
  '';

  installPhase = ''
    runHook preInstall

    make package pkgdir=$out

    rm -rf $out/*_template $out/{pkginfo,README,VERSION} $out/man/web

    mkdir -p $out/share/netpbm
    mv $out/misc $out/share/netpbm/

    moveToOutput bin "''${!outputBin}"

    # wrap any scripts that expect other programs in the package to be in their PATH
    for prog in ppmquant; do
        wrapProgram "''${!outputBin}/bin/$prog" --prefix PATH : "''${!outputBin}/bin"
    done

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = "http://netpbm.sourceforge.net/";
    description = "Toolkit for manipulation of graphic images";
    license = lib.licenses.free; # http://netpbm.svn.code.sourceforge.net/p/netpbm/code/trunk/doc/copyright_summary
    platforms = with stdenv.lib.platforms; linux ++ darwin;
  };
}
