{ stdenv, fetchurl, flex, bison, zlib, boost, gcc, openmpi, readline, gperftools, cgal, metis, scotch, mpfr, gmp, makeWrapper }:

stdenv.mkDerivation rec {
  version = "1912";
  name = "openfoam-v${version}";

  src = fetchurl {
     url = "https://sourceforge.net/projects/openfoam/files/v1912/OpenFOAM-v${version}.tgz";
     sha256 = "437feadf075419290aa8bf461673b723a60dc39525b23322850fb58cb48548f2";
  };

  patches = [ ./includes.patch ];

  # one of the following would bake in the rpath, but sourcing etc/bashrc file updates LD_LIBRARY_PATH
  # NIX_LDFLAGS="-rpath $out/platform/$WM_OPTIONS/lib $NIX_LDFLAGS"
  # NIX_LDFLAGS="${NIX_LDFLAGS/"$out/lib$WM_ARCH_OPTION"/"$out/platform/$WM_OPTIONS/lib"}"
  configurePhase = ''
    echo "CONF START"
    patchShebangs ./
    substituteInPlace etc/bashrc --replace 'projectDir=' '#projectDir=' 
    substituteInPlace etc/bashrc --replace '[ -n "''$projectDir=' '# [ -n "*$projectDir='
    sed -ie 's|PROJECT_DIR=.*|PROJECT_DIR="'"$out"/OpenFOAM-v${version}'"|' etc/bashrc
    sed -ie 's|\[ -n "$projectDir|#\[ -n "$projectDir|' etc/bashrc
    sed -ie 's|\/bin\/cat|cat|' wmake/scripts/have_adios2
    sed -ie 's|BOOST_ARCH_PATH=.*$|BOOST_ARCH_PATH=${boost}|' etc/config.sh/CGAL
    sed -ie 's|$GMP_ARCH_PATH|${gmp}|' etc/config.sh/CGAL
    sed -ie 's|$MPFR_ARCH_PATH|${mpfr}|' etc/config.sh/CGAL
    sed -ie 's|CGAL_ARCH_PATH=.*$|CGAL_ARCH_PATH=${cgal}|' etc/config.sh/CGAL
    sed -ie 's|boost_1_64_0|boost-system|' etc/config.sh/CGAL
    sed -ie 's|CGAL-4.9.1|cgal-system|' etc/config.sh/CGAL
    sed -ie 's|lib$WM_COMPILER_LIB_ARCH|lib|' etc/config.sh/CGAL
    sed -ie 's|METIS_ARCH_PATH=.*$|METIS_ARCH_PATH=${metis}|' etc/config.sh/metis
    sed -ie 's|SCOTCH_ARCH_PATH=.*$|SCOTCH_ARCH_PATH=${scotch}|' etc/config.sh/scotch
    mkdir "$out"
    cp -a ../OpenFOAM-v1912 "$out/"
    cd "$out"/OpenFOAM-v1912
    source etc/bashrc
    echo "CONF DONE"
    export LOGNAME=nix
  '';

  buildPhase = ''
    export WM_NCOMPPROCS="''${NIX_BUILD_CORES}"
    ./Allwmake
  '';

  # stick etc, bin, and platforms under lib/OpenFOAM-${version}
  # fill bin proper up with wrappers that source etc/bashrc for everything in platform/$WM_OPTIONS/bin
  # add -mpi suffixed versions that calls proper mpirun for those with libPstream.so depencies too
  installPhase = ''
    echo "copying etc, bin, and platforms directories to $out/lib/OpenFOAM-v${version}"
    mkdir -p "$out/lib/OpenFOAM-v${version}"
    cp -at "$out/lib/OpenFOAM-v${version}" etc bin platforms
    echo "creating a bin of wrapped binaries from $out/lib/OpenFOAM-v${version}/platforms/$WM_OPTIONS/bin"
    for program in "$out/lib/OpenFOAM-v${version}/platforms/$WM_OPTIONS/bin/"*; do
      makeWrapper "$program" "$out/bin/''${program##*/}" \
        --run "source \"$out/lib/OpenFOAM-v${version}/etc/bashrc\""
      if readelf -d "$program" | fgrep -q libPstream.so; then
        makeWrapper "${openmpi}/bin/mpirun" "$out/bin/''${program##*/}-mpi" \
          --run "[ -r processor0 ] || { echo \"Case is not currently decomposed, see decomposePar documentation\"; exit 1; }" \
          --run "extraFlagsArray+=(-n \"\$(ls -d processor* | wc -l)\" \"$out/bin/''${program##*/}\" -parallel)" \
          --run "source \"$out/lib/OpenFOAM-v${version}/etc/bashrc\""
      fi
    done
    echo "Warning : Any compilation is impossible (codeStream, specific library/solver). Some explanations here : https://nixos.wiki/wiki/FAQ/I_installed_a_library_but_my_compiler_is_not_finding_it._Why%3F"
  '';

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    flex
    bison
    zlib
    boost
    openmpi
    gcc
    readline
    gperftools
    cgal
    metis
    scotch
    mpfr
    gmp
  ];

  meta = with stdenv.lib; {
    homepage = http://www.openfoam.com;
    description = "Free open-source CFD software";
    maintainers = with maintainers; [ CyrilleBonamy ];
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}

