#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script sets up OS build
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
source ~/.bashrc

LOG_FILE="$ROOT_DIR/logs/setup-$(date '+%F_%T').log"

# exits in case there is a temp-tools backup
[ -f "$BROOT/backup/VERSION" ] && exit 0

function clean_cwd(){
    _logger_info "Removing everything from $PWD"

    local cwd=$PWD

    cd $cwd/..
    sudo rm -rf $cwd
    mkdir -vp $cwd
    cd $cwd
}

# --------------------------- STAGE 1 ------------------------------------------

function compile_binutils_1(){
    _logger_info "Compiling binutils part 1"

    ../binutils-*/configure      \
      --prefix=/tools            \
      --with-sysroot=$BROOT      \
      --with-lib-path=/tools/lib \
      --target=$BTARGET          \
      --disable-nls              \
      --disable-werror

    make --jobs 9

    case $(uname -m) in
      x86_64)
        ln -sfv lib /tools/lib64
      ;;
    esac

    make --jobs 9 install
}

function compile_gcc_1(){
    _logger_info "Compiling gcc part 1"

    pushd $BROOT/source/gcc-10.2.0
      mv -v ../mpfr-*/ mpfr/
      mv -v ../gmp-*/ gmp/
      mv -v ../mpc-*/ mpc/

      for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h); do
        cp -fuv $file{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig > $file
        echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
        touch $file.orig
      done

      case $(uname -m) in
        x86_64)
          sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
        ;;
      esac
    popd

    ../gcc-10.2.0/configure                          \
      --target=$BTARGET                              \
      --prefix=/tools                                \
      --with-glibc-version=2.24                      \
      --with-sysroot=$BROOT                          \
      --with-newlib                                  \
      --without-headers                              \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --disable-nls                                  \
      --disable-shared                               \
      --disable-multilib                             \
      --disable-decimal-float                        \
      --disable-threads                              \
      --disable-libatomic                            \
      --disable-libgomp                              \
      --disable-libmpx                               \
      --disable-libquadmath                          \
      --disable-libssp                               \
      --disable-libvtv                               \
      --disable-libstdcxx                            \
      --enable-languages=c,c++

    make --jobs 9

    make --jobs 9 install
}

function install_kernel_headers(){
    _logger_info "Installing Kernel Header Files"

    pushd $BROOT/source/linux-*
      make --jobs 9 mrproper

      make --jobs 9 headers

      sudo find usr/include -name '.*' -delete

      sudo rm -f usr/include/Makefile

      cp -rfuv usr/include /tools
    popd
}

function compile_glibc(){
    _logger_info "Compiling GNU C Library"

    export libc_cv_forced_unwind=yes
    export libc_cv_c_cleanup=yes

    ../glibc-*/configure                            \
      --prefix=/tools                               \
      --host=$BTARGET                               \
      --build=$(../glibc-*/scripts/config.guess)    \
      --enable-kernel=3.2                           \
      --with-headers=/tools/include

    make --jobs 9

    make --jobs 9 install

    unset libc_cv_forced_unwind
    unset libc_cv_c_cleanup
}

function test_toolchain(){
    _logger_info "Performing Toolchain test"

    echo 'int main(){}' > dummy.c; $BTARGET-gcc dummy.c
    local test_glibc=$(readelf -l a.out | grep ': /tools')

    echo $test_glibc | grep -w "/tools/lib64/ld-linux-x86-64.so.2"

    _logger_info "Sanity check - passed"

    rm -vf dummy.c a.out
}

function compile_libcpp(){
    _logger_info "Compiling GNU C++ Library"

    ../gcc-10.2.0/libstdc++-v3/configure         \
      --host=$BTARGET                            \
      --prefix=/tools                            \
      --disable-multilib                         \
      --disable-nls                              \
      --disable-libstdcxx-threads                \
      --disable-libstdcxx-pch                    \
      --with-gxx-include-dir=/tools/$BTARGET/include/c++/10.2.0

    make --jobs 9

    make --jobs 9 install
}

# --------------------------- STAGE 2 ------------------------------------------

function compile_binutils_2(){
    _logger_info "Compiling binutils part 2"

    export CC=$BTARGET-gcc
    export AR=$BTARGET-ar
    export RANLIB=$BTARGET-ranlib

    ../binutils-*/configure      \
      --prefix=/tools            \
      --disable-nls              \
      --disable-werror           \
      --with-lib-path=/tools/lib \
      --with-sysroot

    make --jobs 9

    make --jobs 9 install

    make --directory ld clean
    make --directory ld LIB_PATH=/usr/lib:/lib

    cp -fuv ld/ld-new /tools/bin
}

function compile_gcc_2(){
    _logger_info "Compiling gcc part 2"

    pushd $BROOT/source/gcc-10.2.0
      cat gcc/limitx.h gcc/glimits.h gcc/limity.h >  \
        `dirname $($BTARGET-gcc -print-libgcc-file-name)`/include-fixed/limits.h
    popd

    export CC=$BTARGET-gcc
    export CXX=$BTARGET-g++
    export AR=$BTARGET-ar
    export RANLIB=$BTARGET-ranlib

    ../gcc-10.2.0/configure                          \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp

    make --jobs 9

    make --jobs 9 install

    ln -sfv gcc /tools/bin/cc

    unset CC CXX AR RANLIB
}

# --------------------------- PACKAGES/UTILS -----------------------------------

function compile_tcl(){
    _logger_info "Compiling TCL"

    pushd ../tcl*/unix/
      ./configure --prefix=/tools

      make --jobs 9

      make --jobs 9 install

      chmod -v u+w /tools/lib/libtcl*.*.so

      make --jobs 9 install-private-headers

      ln -sfv tclsh8.6 /tools/bin/tclsh
    popd
}

function compile_expect(){
    _logger_info "Compiling expect"

    pushd ../expect*/
      cp -fuv configure{,.orig}

      sed 's:/usr/local/bin:/bin:' configure.orig > configure

      ./configure --prefix=/tools       \
        --with-tcl=/tools/lib           \
        --with-tclinclude=/tools/include

      make --jobs 9

      make --jobs 9 SCRIPTS="" install # will skip including supplemental scripts
    popd
}

function compile_dejagnu(){
    _logger_info "Compiling dejagnu"

    pushd ../dejagnu-*/
      ./configure --prefix=/tools

      make --jobs 9 install
    popd
}

function compile_check(){
    _logger_info "Compiling check"

    pushd ../check-*/
      PKG_CONFIG= ./configure --prefix=/tools # PKG_CONFIG= prevents any pre-defined pkg-config options

      make --jobs 9

      make --jobs 9 install
    popd
}

function compile_ncurses(){
    _logger_info "Compiling ncurses"

    pushd ../ncurses-*/
      sed -i 's/mawk//' configure # ensures that gawk command is found before awk

      ./configure --prefix=/tools \
        --with-shared             \
        --without-debug           \
        --without-ada             \
        --enable-widec            \
        --enable-overwrite

      make --jobs 9

      make --jobs 9 install

      ln -sfv libncursesw.so /tools/lib/libncurses.so
    popd
}

function compile_bash(){
    _logger_info "Compiling bash"

    pushd ../bash-*/
      ./configure --prefix=/tools --without-bash-malloc

      make --jobs 9

      make --jobs 9 install

      ln -sfv bash /tools/bin/sh
    popd
}

function compile_bzip2(){
    _logger_info "Compiling bzip2"

    pushd ../bzip2-*/
      make --jobs 9 --file Makefile-libbz2_so

      make --jobs 9 clean

      make --jobs 9

      make --jobs 9 PREFIX=/tools install

      cp -fuv bzip2-shared /tools/bin/bzip2
      cp -afuv libbz2.so* /tools/lib

      ln -sfv libbz2.so.1.0 /tools/lib/libbz2.so
    popd
}

function compile_coreutils(){
    _logger_info "Compiling coreutils"

    pushd ../coreutils-*/
    	./configure --prefix=/tools --enable-install-program=hostname

      make --jobs 9

      make --jobs 9 install
    popd
}

function compile_gettext(){
    _logger_info "Compiling gettext"

    pushd ../gettext-*/
    	EMACS="no" ./configure --prefix=/tools --disable-shared

      make --jobs 9

      cp -fuv gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
    popd
}

function compile_make(){
    _logger_info "Compiling make"

    pushd ../make-*/
      # workaround an error caused by glibc-2.27:
      # sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c

    	./configure --prefix=/tools --without-guile

      make --jobs 9

      make --jobs 9 install
    popd
}

function compile_perl(){
    _logger_info "Compiling perl"

    pushd ../perl-5.32.1/
    	sh Configure -des -Dprefix=/tools -Dlibs=-lm

      make --jobs 9

      cp -fuv perl cpan/podlators/scripts/pod2man /tools/bin

      mkdir -vp /tools/lib/perl5/5.32.1

      cp -rfuv lib/* /tools/lib/perl5/5.32.1
    popd
}

function compile_python(){
    _logger_info "Compiling Python"

    pushd ../Python-*/
    	# sed -i '/def add_multiarch_paths/a \        return' setup.py
      ./configure --prefix=/tools --enable-shared --without-ensurepip

      make --jobs 9

      make --jobs 9 install
    popd
}

function compile_util-linux(){
    _logger_info "Compiling util-linux"

    pushd ../util-linux-*/
    	PKG_CONFIG= ./configure --prefix=/tools \
        --without-python                      \
        --disable-makeinstall-chown           \
        --without-systemdsystemunitdir        \
        --without-ncurses

      make --jobs 9

      make --jobs 9 install
    popd
}

function compile_m4(){
    _logger_info "Compiling m4"

    pushd ../m4-*/
      ./configure --prefix=/tools             \
        --host=$BTARGET                       \
        --build=$(../m4-*/build-aux/config.guess)

      make --jobs 9

      make --jobs 9 DESTDIR=$BROOT install
    popd
}

function compile_basic_packages(){
    for pkg in {bison,diffutils,file,findutils,gawk,grep,gzip,patch,sed,tar,texinfo,xz}; do
      _logger_info "Compiling $pkg"

      pushd ../$pkg-*/
        ./configure --prefix=/tools

        make --jobs 9

        make --jobs 9 install
      popd
    done
}

# --------------------------- CLEANING/BACKUP -----------------------------------

function compilation_stripping(){
    _logger_info "Compilation Cleaning"

    strip --strip-debug /tools/lib/* || true
    /usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true

    rm -rf /tools/{,share}/{info,man,doc}

    find /tools/lib{,exec} -name \*.la -delete
}

function backup_temp-tools(){
    _logger_info "Backing up build temptools"

    cd $BROOT

    sudo chown -R root: $BROOT/tools

    sudo tar --ignore-failed-read --exclude="source" -cJpf $ROOT_DIR/backup-temp-tools-$BVERSION.tar.xz .
}

function main(){
# ------- STAGE 1 -------

    compile_binutils_1
    clean_cwd

    compile_gcc_1
    clean_cwd

    install_kernel_headers

    compile_glibc
    clean_cwd

    test_toolchain

    compile_libcpp
    clean_cwd

# ------- STAGE 2 -------

    compile_binutils_2
    clean_cwd

    compile_gcc_2
    clean_cwd

    test_toolchain

# ---- PACKAGES/UTILS ----

    # compile_tcl
    # compile_expect
    # compile_dejagnu
    # compile_check
    compile_ncurses
    compile_bash
    # compile_bzip2
    compile_coreutils
    compile_gettext
    compile_make
    compile_perl
    compile_python
    compile_util-linux
    compile_m4
    compile_basic_packages

# --- CLEANING/BACKUP ---

    compilation_stripping
    backup_temp-tools

    exit 0
}

main 2>&1 | sudo tee -a $LOG_FILE
