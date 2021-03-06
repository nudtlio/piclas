#!/bin/bash -i

#==============================================================================
# title       : InstallMPIallCOMPILERS.sh
# description : This script installs openmpi or mpich in a pre-installed module 
#               env for all compiler that are found and able to be loaded
# date        : Nov 27, 2019
# version     : 1.0   
# usage       : bash InstallMPIallCOMPILERS.sh
# notes       : Bash in run interactively via "-i" to use "module load/purge" 
#               commands
#==============================================================================

# chose which mpi you want to have installed (openmpi or mpich)
WHICHMPI=openmpi
# choose for which compilers mpi is build (gcc or intel)
WHICHCOMPILER=gcc

if [ "${WHICHMPI}" == "openmpi" ]; then
  # DOWNLOAD and INSTALL OPENMPI (example OpenMPI-2.1.6)
  #MPIVERSION=2.1.6
  #MPIVERSION=3.1.3
  #MPIVERSION=3.1.4
  #MPIVERSION=4.0.1
  MPIVERSION=4.0.2
elif [ "${WHICHMPI}" == "mpich" ]; then
  # DOWNLOAD and INSTALL MPICH (example mpich-3.2.0)
  MPIVERSION=3.2
else
  echo "flag neither 'openmpi' nor 'mpich'"
  echo "no mpi installed"
  exit
fi

if [ "${WHICHCOMPILER}" == "gcc" ] || [ "${WHICHCOMPILER}" == "intel" ]; then
  INSTALLDIR=/opt
  SOURCEDIR=/opt/Installsources
  MPIINSTALLDIR=${INSTALLDIR}/${WHICHMPI}/${MPIVERSION}
  MODULESDIR=/opt/modules/modulefiles
  MODULETEMPLATESDIR=/opt/Installsources/moduletemplates
  MODULETEMPLATENAME=template

  if [ ! -d "${SOURCEDIR}" ]; then
    mkdir -p ${SOURCEDIR}
  fi

  # check how many ${WHICHCOMPILER} compilers are installed
  NCOMPILERS=$(ls ${MODULESDIR}/compilers/${WHICHCOMPILER}/ | sed 's/ /\n/g' | grep -i "[0-9]\." | wc -l)
  # loop over all found compilers
  for i in $(seq 1 ${NCOMPILERS}); do
    # 'i'th compiler installed
    COMPILERVERSION=$(ls ${MODULESDIR}/compilers/${WHICHCOMPILER}/ | sed 's/ /\n/g' | grep -i "[0-9]\." | head -n ${i} | tail -n 1)
    MPIMODULEFILEDIR=${MODULESDIR}/MPI/${WHICHMPI}/${MPIVERSION}/${WHICHCOMPILER}
    MPIMODULEFILE=${MPIMODULEFILEDIR}/${COMPILERVERSION}
    if [[ -n ${1} ]]; then
      if [[ ${1} =~ ^-r(erun)?$ ]] && [[ -f ${MPIMODULEFILE} ]]; then
        rm ${MPIMODULEFILE}
      fi
    fi
    # if no mpi module for this compiler found, install ${WHICHMPI} and create module
    if [ ! -e "${MPIMODULEFILE}" ]; then
      echo "creating ${WHICHMPI}-${MPIVERSION} for ${WHICHCOMPILER}-${COMPILERVERSION}"

      if [[ -n $(module purge 2>&1) ]]; then
        echo "module: command not found"
        exit
      fi
      module purge

      if [[ -n $(module load ${WHICHCOMPILER}/${COMPILERVERSION} 2>&1) ]]; then
        echo "module ${WHICHCOMPILER}/${COMPILERVERSION} not found "
        break
      fi
      module load ${WHICHCOMPILER}/${COMPILERVERSION}
      module list

      # build and installation
      cd ${SOURCEDIR}
      if [ "${WHICHMPI}" == "openmpi" ]; then
        if [ ! -e "${SOURCEDIR}/${WHICHMPI}-${MPIVERSION}.tar.gz" ]; then
          wget "https://www.open-mpi.org/software/ompi/v${MPIVERSION%.*}/downloads/openmpi-${MPIVERSION}.tar.gz"
        fi
        if [ ! -e "${SOURCEDIR}/openmpi-${MPIVERSION}.tar.gz" ]; then
          echo "no mpi install-file downloaded for OpenMPI-${MPIVERSION}"
          echo "check if https://www.open-mpi.org/software/ompi/v${MPIVERSION%.*}/downloads/openmpi-${MPIVERSION}.tar.gz exists"
          break
        fi
      elif [ "${WHICHMPI}" == "mpich" ]; then
        if [ ! -e "${SOURCEDIR}/mpich-${MPIVERSION}.tar.gz" ]; then
          wget "http://www.mpich.org/static/downloads/${MPIVERSION}/mpich-${MPIVERSION}.tar.gz"
        fi
        if [ ! -e "${SOURCEDIR}/mpich-${MPIVERSION}.tar.gz" ]; then
          echo "no mpi install-file downloaded for MPICH-${MPIVERSION}"
          echo "check if http://www.mpich.org/static/downloads/${MPIVERSION}/mpich-${MPIVERSION}.tar.gz exists"
          break
        fi
      fi
      tar -xzf ${WHICHMPI}-${MPIVERSION}.tar.gz
      if [ ! -e "${SOURCEDIR}/${WHICHMPI}-${MPIVERSION}/build_${WHICHCOMPILER}-${COMPILERVERSION}" ]; then
        mkdir -p ${SOURCEDIR}/${WHICHMPI}-${MPIVERSION}/build_${WHICHCOMPILER}-${COMPILERVERSION}
      fi
      if [[ ${1} =~ ^-r(erun)?$ ]] ; then
        rm ${SOURCEDIR}/${WHICHMPI}-${MPIVERSION}/build_${WHICHCOMPILER}-${COMPILERVERSION}/* 
      fi
      cd ${SOURCEDIR}/${WHICHMPI}-${MPIVERSION}/build_${WHICHCOMPILER}-${COMPILERVERSION}

      if [ "${WHICHCOMPILER}" == "gcc" ]; then
        ../configure --prefix=${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION} CC=$(which gcc) CXX=$(which g++) FC=$(which gfortran)
      elif [ "${WHICHCOMPILER}" == "intel" ]; then
        ../configure --prefix=${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION} CC=$(which icc) CXX=$(which icpc) FC=$(which ifort)
      fi
      make -j 2 2>&1 | tee make.out
      if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo " "
        echo "Failed: [make -j 2 2>&1 | tee make.out]"
        break
      else
        make install 2>&1 | tee install.out
      fi

      # create modulefile if installation seems succesfull (check if mpicc, mpicxx, mpifort exists in installdir)
      if [ -e "${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION}/bin/mpicc" ] && [ -e "${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION}/bin/mpicxx" ] && [ -e "${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION}/bin/mpifort" ]; then
        if [ ! -d "${MPIMODULEFILEDIR}" ]; then
          mkdir -p ${MPIMODULEFILEDIR}
        fi
        cp ${MODULETEMPLATESDIR}/MPI/${MODULETEMPLATENAME} ${MPIMODULEFILE}
        sed -i 's/whichcompiler/'${WHICHCOMPILER}'/gI' ${MPIMODULEFILE}
        sed -i 's/compilerversion/'${COMPILERVERSION}'/gI' ${MPIMODULEFILE}
        sed -i 's/whichmpi/'${WHICHMPI}'/gI' ${MPIMODULEFILE}
        sed -i 's/mpiversion/'${MPIVERSION}'/gI' ${MPIMODULEFILE}
      else
        echo "No module file created for ${WHICHMPI}-${MPIVERSION} for ${WHICHCOMPILER}-${COMPILERVERSION}"
        echo "No mpi found in ${MPIINSTALLDIR}/${WHICHCOMPILER}/${COMPILERVERSION}/bin"
      fi

    else
      echo "${WHICHMPI}-${MPIVERSION} for ${WHICHCOMPILER}-${COMPILERVERSION} already created (module file exists)"
      continue
    fi
  done
  #cd ${SOURCEDIR}
  #rm -rf ${WHICHMPI}-${MPIVERSION}.tar.gz
else
  echo "WHICHCOMPILER-flag neither 'gcc' nor 'intel'"
  echo "no mpi installed"
  exit
fi
