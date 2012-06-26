haskell_install
===============

haskell: install script: from scratch, to fully customized and up-to-date user installation (shell script for Debian-based distributions)

# RATIONALE

Mixing user, distribution and global installations may in the long run corrupt the package database. Better to use a user installation from the beginning. More information at: http://www.vex.net/~trebla/haskell/sicp.xhtml

# USAGE
  a) set the haskell path in your .bashrc
  
       export HASKELL_PATH=$HOME/haskell/.cabal/bin:$HOME/haskell/usr/bin
       
       export PATH=${HASKELL_PATH}:${PATH}
       
  b) run this script


# CONFIGURATION
Global variables are at the top of the script. Order of execution is set in the main function, at the bottom.
