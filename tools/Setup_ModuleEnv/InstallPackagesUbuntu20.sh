#!/bin/bash

#==============================================================================
# title       : InstallPackages.sh
# description : This script installs the software packages required for 
#               the module env scripts for creating a software environment for 
#               PICLas/FLEXI code frameworks
# date        : Nov 27, 2019
# version     : 1.0   
# usage       : bash InstallPackages.sh
# notes       : 
#==============================================================================

# Check for updates
sudo apt-get update

# compiler
sudo apt-get install make cmake cmake-curses-gui gfortran g++ gcc 

# filesystem operations
sudo apt-get install  libboost-dev

# cmake: developer's libraries for ncurses
sudo apt-get install  libncurses-dev  libncurses5-dev

# ctags 
sudo apt-get install  exuberant-ctags

# blas and lapack
sudo apt-get install  libblas-dev  liblapack3  liblapack-dev

# tcl (required for module install scripts)
sudo apt-get install  tcl  tcl8.6-dev

# zlib is a library implementing the deflate compression method found in gzip and PKZIP (development)
sudo apt-get install   zlib1g-dev

# Linux Standard Base support package (LSB): required on, e.g., Ubuntu Server that is equipped only thinly with pre-installed software
sudo apt-get install  lsb

# Secure Sockets Layer toolkit - development files
sudo apt-get install  libssl-dev

# Create Installsources directory and copy the module templates
sudo mkdir -p /opt/Installsources
sudo cp -r moduletemplates /opt/Installsources/moduletemplates
