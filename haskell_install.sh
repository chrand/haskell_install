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
v=7.4.2
# repository ROOT
h_root=$HOME/prj/tools/haskell_repository
#---------------------------------------------------------------
down_root=$h_root/download
ghc_v=ghc-$v
ghc_root=$h_root/$ghc_v
cabal_root=$ghc_root/.cabal
# architecture
arch=$(uname -m)
[[ "$arch" != "x86_64" ]] && arch="i386"
# ghc
ghc_pkg=ghc-$v-$arch-unknown-linux.tar.bz2
ghc_url=http://www.haskell.org/ghc/dist/$v/$ghc_pkg
# cabal
hackage_url=http://hackage.haskell.org
cabal_url=$hackage_url/package/cabal-install
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
function download() {
  debug_msg download
  # ghc
  ghc_pkg_full=$down_root/$ghc_pkg
  [[ ! -f "$ghc_pkg_full" ]] && wget $ghc_url -O $ghc_pkg_full
  # cabal-install
  cabal_pkg_url=$hackage_url/$(wget -q $cabal_url -O - | grep --color=never "archive/cabal-install.*tar"|sed -r -e 's|.*"([^"]+)"|\1|g')
  cabal_pkg_full=$down_root/$(basename $cabal_pkg_url)
  [[ ! -f "$cabal_pkg_full" ]] && wget $cabal_pkg_url -O $cabal_pkg_full
}
#---------------------------------------------------------------
function ghc_install() {
  debug_msg ghc_install
  [[ -f $ghc_root/usr/bin/runghc ]] && return
  # install
  cd $down_root || exit 1
  tar -jxf $ghc_pkg || exit 1
  cd ghc-$v || exit 1
  ./configure --prefix=$ghc_root/usr || exit 1
  nice make install || exit 1
}
#---------------------------------------------------------------
function cabal_install() {
  debug_msg cabal_install
  [[ -f $ghc_root/.cabal/bin/cabal ]] && return
  # install
  cd $down_root || exit 1
  tar -zxf $(ls cabal*tar*|tail -1) || exit 1
  cd cabal* || exit 1
  nice bash ./bootstrap.sh || exit 1
}
#---------------------------------------------------------------
function cabal_config_write() {
  debug_msg cabal_config_write
  [[ -f $cabal_root/config ]] && return
  nice cabal update || exit 1
  sed -rie 's/-- library-profiling: False/library-profiling: True/;s/-- documentation: False/documentation: True/;s|-- prefix: (.+)/.cabal|prefix: \1/haskell/usr|;s|-- docdir: \$datadir/doc/\$pkgid|docdir: \$datadir/doc/\$compiler/\$pkgid|' $cabal_root/config || exit 1
}
#---------------------------------------------------------------
function cabal_reinstall_for_profiling() {
  debug_msg cabal_reinstall_for_profiling
  [[ -f $HOME/haskell/usr/bin/happy ]] && return
  cabal install --reinstall $(ghc-pkg list | awk -v p=0 '/\.ghc/{p=1} p==1 && /^ /{print $0}') || exit 1
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
  [[ -f $HOME/haskell/usr/bin/c2hs ]] && return
  for pkg in happy alex c2hs; do
    _cabal_install_pkg $pkg
  done
}
#---------------------------------------------------------------
function packages_user() {
  debug_msg packages_user
  for pkg in \
    hscolour \
    criterion \
    repa repa-io repa-algorithms \
    cuda \
    accelerate-io accelerate-cuda \
    ; do
    _cabal_install_pkg $pkg
  done
    # language-c-quote: infinite wait
    # repa-examples accelerate-examples
}
#=========================================================================
# MAIN
#=========================================================================
# dependencies_check
dirs_make
links_make
download
ghc_install
cabal_install
cabal_config_write
cabal_reinstall_for_profiling
packages_system
# packages_user
