#!/bin/bash
# INFORMATION on why a user installation is best:
#     http://www.vex.net/~trebla/haskell/sicp.xhtml
# USAGE:
#   a) set the haskell path in your .bashrc
#        export HASKELL_PATH=$HOME/haskell/.cabal/bin:$HOME/haskell/usr/bin
#        export PATH=${HASKELL_PATH}:${PATH}
#   b) run this script
#=========================================================================
# USER variables
#=========================================================================
# GHC version
gv=7.4.1
plat_v=2012.2.0.0 # comment this line to install all libraries from scratch
# repository ROOT
h_root=$HOME/prj/tools/haskell_repository
#---------------------------------------------------------------
down_root=$h_root/download
ghc_v=ghc-$gv
ghc_root=$h_root/$ghc_v
cabal_root=$ghc_root/.cabal
# architecture
arch=$(uname -m)
[[ "$arch" != "x86_64" ]] && arch="i386"
# ghc
ghc_pkg=$ghc_v-$arch-unknown-linux.tar.bz2
ghc_url=http://www.haskell.org/ghc/dist/$gv/$ghc_pkg
# haskell platform
plat_pkg=haskell-platform-${plat_v}.tar.gz
plat_url=http://lambda.haskell.org/platform/download/$plat_v/$plat_pkg
# cabal
hackage_url=http://hackage.haskell.org
cabal_url=$hackage_url/package/cabal-install
# prefix
prefix=$ghc_root/usr
#=========================================================================
# HELPER FUNCTIONS
#=========================================================================
function debug_msg() {
  echo "# DEBUG: $@"
}
#---------------------------------------------------------------
function dependencies_check() {
  debug_msg dependencies_check
  to_install=""
  for pkg in libbsd-dev libgmp3-dev zlib1g-dev freeglut3-dev; do
    pkg_list_file=$(find /var/lib/dpkg/info/ | grep list | grep -i $pkg)
    if [[ -z "$pkg_list_file" ]]; then
      to_install="$to_install $pkg"
    fi
  done
  if [[ -n "$to_install" ]]; then
    echo "# ERROR: This packages should be installed:"
    echo "# sudo aptitude install $to_install"
    exit 1
  fi
}
#---------------------------------------------------------------
function dirs_make() {
  debug_msg dirs_make
  mkdir -p $ghc_root $down_root $cabal_root
}
#---------------------------------------------------------------
function links_make() {
  debug_msg links_make
  cd $HOME
  # haskell link
  rm -f haskell
  ln -sf $ghc_root haskell
  # .ghc, .cabal
  for dir in .ghc .cabal; do
    mkdir -p $ghc_root/$dir
    ln -sf $ghc_root/$dir .
  done
}
#---------------------------------------------------------------
function ghc_install() {
  debug_msg ghc_install
  [[ -f $prefix/bin/runghc ]] && return
  # download
  cd $down_root || exit 1
  ghc_pkg_full=$down_root/$ghc_pkg
  [[ ! -f "$ghc_pkg_full" ]] && wget $ghc_url -O $ghc_pkg_full
  # install
  tar -jxf $ghc_pkg || exit 1
  cd $ghc_v || exit 1
  ./configure --prefix=$prefix || exit 1
  nice make install || exit 1
}
#---------------------------------------------------------------
function haskell_platform_install() {
  debug_msg haskell_platform_install
  [[ -f $HOME/haskell/usr/bin/happy ]] && return
  # download
  cd $down_root || exit 1
  plat_pkg_full=$down_root/$plat_pkg
  [[ ! -f "$plat_pkg_full" ]] && wget $plat_url -O $plat_pkg
  # install
  tar -zxf $plat_pkg || exit 1
  cd $(basename $plat_pkg .tar.gz) || exit 1
  ./configure --prefix=$prefix || exit 1
  nice make install || exit 1
}
#---------------------------------------------------------------
function cabal_install() {
  debug_msg cabal_install
  [[ -f $ghc_root/.cabal/bin/cabal ]] && return
  # download
  cd $down_root || exit 1
  cabal_pkg_url=$hackage_url/$(wget -q $cabal_url -O - | grep --color=never "archive/cabal-install.*tar"|sed -r -e 's|.*"([^"]+)"|\1|g')
  cabal_pkg_full=$down_root/$(basename $cabal_pkg_url)
  [[ ! -f "$cabal_pkg_full" ]] && wget $cabal_pkg_url -O $cabal_pkg_full
  # install
  tar -zxf $(ls cabal*tar*|tail -1) || exit 1
  cd cabal* || exit 1
  nice bash ./bootstrap.sh || exit 1
}
#---------------------------------------------------------------
function cabal_config_write() {
  debug_msg cabal_config_write
  [[ -f $cabal_root/config ]] && return
  nice cabal update || exit 1
  sed -i -r -e 's/-- library-profiling: False/library-profiling: True/;s/-- documentation: False/documentation: True/;s|-- prefix: (.+)/.cabal|prefix: \1/haskell/usr|;s|-- docdir: \$datadir/doc/\$pkgid|docdir: \$datadir/doc/\$compiler/\$pkgid|' $cabal_root/config || exit 1
}
#---------------------------------------------------------------
function cabal_reinstall_for_profiling_and_documentation() {
  debug_msg cabal_reinstall_for_profiling_and_documentation
  [[ -f $prefix/bin/HsColour ]] && return
  _cabal_install_pkg hscolour
  cabal install --reinstall --force-reinstalls $(ghc-pkg list | awk -v p=0 '/\.ghc/{p=1} p==1 && /^ /{print $0}' | grep -v 'haskell-platform') || exit 1
}
#---------------------------------------------------------------
function _cabal_install_pkg() {
  debug_msg _cabal_install_pkg
  local pkg="$1"
  # already registered? skip installation
  ghc-pkg list | grep -v package.conf.d | grep -Eiq "$pkg-[[:digit:]+.*]+" && return
  echo "#==== INSTALLING $pkg ===="
  nice cabal install $pkg || exit 1
}
#---------------------------------------------------------------
function packages_system() {
  debug_msg packages_system
  for pkg in happy alex c2hs; do
    [[ ! -f $prefix/bin/$pkg ]] && _cabal_install_pkg $pkg
  done
}
#---------------------------------------------------------------
function packages_user() {
  debug_msg packages_user
  for pkg in \
    criterion \
    repa-examples \
    cuda accelerate-cuda accelerate-examples \
    ; do
    _cabal_install_pkg $pkg
  done
}
#=========================================================================
# MAIN
#=========================================================================
# dependencies_check
dirs_make
links_make
ghc_install
[[ -z "$plat_v" ]] && cabal_install || haskell_platform_install
cabal_config_write
cabal_reinstall_for_profiling_and_documentation
packages_system
packages_user
