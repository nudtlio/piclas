!==================================================================================================================================
! Copyright (c) 2019 Prof. Claus-Dieter Munz and Prof. Stefanos Fasoulas
!
! This file is part of PICLas (gitlab.com/piclas/piclas). PICLas is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3
! of the License, or (at your option) any later version.
!
! PICLas is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with PICLas. If not, see <http://www.gnu.org/licenses/>.
!==================================================================================================================================
#include "piclas.h"

MODULE MOD_SuperB_Init
!===================================================================================================================================
!>
!===================================================================================================================================
IMPLICIT NONE
PRIVATE
!----------------------------------------------------------------------------------------------------------------------------------
PUBLIC :: InitializeSuperB, DefineParametersSuperB, FinalizeSuperB
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for SuperB
!==================================================================================================================================
SUBROUTINE DefineParametersSuperB()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: prms
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("SuperB")

CALL prms%CreateLogicalOption('xxxxxxxx'      , "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",'.FALSE.')

CALL prms%CreateIntOption(    'xxxxxxxx'   , "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",'0')

CALL prms%CreateRealOption(   'xxxxxxxx'       , "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",'1.')

END SUBROUTINE DefineParametersSuperB


SUBROUTINE InitializeSuperB()
!===================================================================================================================================
!>
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Globals_Vars            ,ONLY: PI
USE MOD_PICInterpolation_Vars   ,ONLY: BGFieldVTKOutput
USE MOD_SuperB_Vars
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: ALLOCSTAT
INTEGER                   :: iMagnet, iCoil, iSegment, iCoilTemp
CHARACTER(LEN=32)         :: hilf,hilf2
!===================================================================================================================================

! Output of the magnets/coils as separate VTK files
BGFieldVTKOutput         = GETLOGICAL('PIC-CalcBField-OutputVTK','.FALSE.')
! Get the number of magnets
NumOfCuboidMagnets       = GETINT('NumOfCuboidMagnets','0')
NumOfSphericMagnets      = GETINT('NumOfSphericMagnets','0')
NumOfCylindricMagnets    = GETINT('NumOfCylindricMagnets','0')
NumOfConicMagnets        = GETINT('NumOfConicMagnets','0')
NumOfCoils               = GETINT('NumOfCoils','0')
NumOfCircleCoils         = GETINT('NumOfCircleCoils','0')
NumOfRectangleCoils      = GETINT('NumOfRectangleCoils','0')
NumOfLinearConductors    = GETINT('NumOfLinearConductors','0')
! Allocate the magnets
ALLOCATE(CuboidMagnetInfo(NumOfCuboidMagnets))
ALLOCATE(SphericMagnetInfo(NumOfSphericMagnets))
ALLOCATE(CylindricMagnetInfo(NumOfCylindricMagnets))
ALLOCATE(ConicMagnetInfo(NumOfConicMagnets))
ALLOCATE(CoilInfo(NumOfCoils))
ALLOCATE(CircleCoilInfo(NumOfCircleCoils))
ALLOCATE(RectangleCoilInfo(NumOfRectangleCoils))
ALLOCATE(LinearConductorInfo(NumOfLinearConductors))
ALLOCATE(TimeDepCoil(NumOfCoils+NumOfCircleCoils+NumOfRectangleCoils+NumOfLinearConductors))
ALLOCATE(CurrentInfo(NumOfCoils+NumOfCircleCoils+NumOfRectangleCoils+NumOfLinearConductors))
! Iterate over all cuboid magnets
IF (NumOfCuboidMagnets.GT.0) THEN
  DO iMagnet = 1,NumOfCuboidMagnets
    SWRITE(*,*) "|       Read in Infos of cuboid Magnet |", iMagnet

    WRITE(UNIT=hilf,FMT='(I3)') iMagnet
    CuboidMagnetInfo(iMagnet)%BasePoint(1:3)     = GETREALARRAY('CuboidMagnet'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    CuboidMagnetInfo(iMagnet)%BaseVector1(1:3)   = GETREALARRAY('CuboidMagnet'//TRIM(hilf)//'-BaseVector1',3,'0.,0.,0.')
    CuboidMagnetInfo(iMagnet)%BaseVector2(1:3)   = GETREALARRAY('CuboidMagnet'//TRIM(hilf)//'-BaseVector2',3,'0.,0.,0.')
    CuboidMagnetInfo(iMagnet)%BaseVector3(1:3)   = GETREALARRAY('CuboidMagnet'//TRIM(hilf)//'-BaseVector3',3,'0.,0.,0.')
    CuboidMagnetInfo(iMagnet)%NumNodes           = GETINT('CuboidMagnet'//TRIM(hilf)//'-NumNodes','1')
    CuboidMagnetInfo(iMagnet)%Magnetisation(1:3) = GETREALARRAY('CuboidMagnet'//TRIM(hilf)//'-Magnetisation',3,'0.,0.,0.')
  ENDDO
ENDIF
! Iterate over all spheric magnets
IF (NumOfSphericMagnets.GT.0) THEN
  DO iMagnet = 1,NumOfSphericMagnets
    SWRITE(*,*) "|       Read in Infos of spheric Magnet |", iMagnet

    WRITE(UNIT=hilf,FMT='(I3)') iMagnet
    SphericMagnetInfo(iMagnet)%BasePoint(1:3)     = GETREALARRAY('SphericMagnet'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    SphericMagnetInfo(iMagnet)%Radius             = GETREAL('SphericMagnet'//TRIM(hilf)//'-Radius','1')
    SphericMagnetInfo(iMagnet)%NumNodes           = GETINT('SphericMagnet'//TRIM(hilf)//'-NumNodes','1')
    SphericMagnetInfo(iMagnet)%Magnetisation(1:3) = GETREALARRAY('SphericMagnet'//TRIM(hilf)//'-Magnetisation',3,'0.,0.,0.')
  ENDDO
ENDIF
! Iterate over all cylindric magnets
IF (NumOfCylindricMagnets.GT.0) THEN
  DO iMagnet = 1,NumOfCylindricMagnets
    SWRITE(*,*) "|       Read in Infos of cylindric Magnet |", iMagnet

    WRITE(UNIT=hilf,FMT='(I3)') iMagnet
    CylindricMagnetInfo(iMagnet)%BasePoint(1:3)     = GETREALARRAY('CylindricMagnet'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    CylindricMagnetInfo(iMagnet)%HeightVector(1:3)  = GETREALARRAY('CylindricMagnet'//TRIM(hilf)//'-HeightVector',3,'0.,0.,0.')
    CylindricMagnetInfo(iMagnet)%Radius             = GETREAL('CylindricMagnet'//TRIM(hilf)//'-Radius','1.')
    CylindricMagnetInfo(iMagnet)%NumNodes           = GETINT('CylindricMagnet'//TRIM(hilf)//'-NumNodes','1')
    CylindricMagnetInfo(iMagnet)%Magnetisation(1:3) = GETREALARRAY('CylindricMagnet'//&
                                                      TRIM(hilf)//'-Magnetisation',3,'0.,0.,0.')
  ENDDO
ENDIF
! Iterate over all conic magnets
IF (NumOfConicMagnets.GT.0) THEN
  DO iMagnet = 1,NumOfConicMagnets
    SWRITE(*,*) "|      Read in Infos of conic Magnets |", iMagnet

    WRITE(UNIT=hilf,FMT='(I3)') iMagnet
    ConicMagnetInfo(iMagnet)%BasePoint(1:3)     = GETREALARRAY('ConicMagnet'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    ConicMagnetInfo(iMagnet)%HeightVector(1:3)  = GETREALARRAY('ConicMagnet'//TRIM(hilf)//'-HeightVector',3,'0.,0.,0.')
    ConicMagnetInfo(iMagnet)%Radius1            = GETREAL('ConicMagnet'//TRIM(hilf)//'-Radius1','1.')
    ConicMagnetInfo(iMagnet)%Radius2            = GETREAL('ConicMagnet'//TRIM(hilf)//'-Radius2','1.')
    ConicMagnetInfo(iMagnet)%NumNodes           = GETINT('ConicMagnet'//TRIM(hilf)//'-NumNodes','1')
    ConicMagnetInfo(iMagnet)%Magnetisation(1:3) = GETREALARRAY('ConicMagnet'//TRIM(hilf)//'-Magnetisation',3,'0.,0.,0.')
  ENDDO
ENDIF
! Iterate over all coils
IF (NumOfCoils.GT.0) THEN
  DO iCoil = 1,NumOfCoils
    SWRITE(*,*) "|       Read in Infos of coil |", iCoil

    WRITE(UNIT=hilf,FMT='(I3)') iCoil
    CoilInfo(iCoil)%BasePoint(1:3) = GETREALARRAY('Coil'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    CoilInfo(iCoil)%LengthVector(1:3) = GETREALARRAY('Coil'//TRIM(hilf)//'-LengthVector',3,'0.,0.,0.')
    CoilInfo(iCoil)%Length = SQRT(CoilInfo(iCoil)%LengthVector(1)**2 +& 
                                  CoilInfo(iCoil)%LengthVector(2)**2 +&
                                  CoilInfo(iCoil)%LengthVector(3)**2)
    CoilInfo(iCoil)%AxisVec1 = GETREALARRAY('Coil'//TRIM(hilf)//'-AxisVec1',3,'0.,0.,0.')
    IF (DOT_PRODUCT(CoilInfo(iCoil)%LengthVector,CoilInfo(iCoil)%AxisVec1).NE.0) THEN
      CALL abort(__STAMP__, &
      'ERROR in pic_interpolation.f90: Length Vector and Axis Vector of coil need to be orthogonal!',ALLOCSTAT)
    ENDIF
    TimeDepCoil(iCoil) = GETLOGICAL('Coil'//TRIM(hilf)//'-TimeDepCoil','.FALSE.')
    IF(TimeDepCoil(iCoil)) THEN
      CurrentInfo(iCoil)%CurrentAmpl = GETREAL('Coil'//TRIM(hilf)//'-CurrentAmpl','0.')
      CurrentInfo(iCoil)%CurrentFreq = GETREAL('Coil'//TRIM(hilf)//'-CurrentFreq','0.')
      CurrentInfo(iCoil)%CurrentPhase = GETREAL('Coil'//TRIM(hilf)//'-CurrentPhase','0.')
    ELSE
      CoilInfo(iCoil)%Current = GETREAL('Coil'//TRIM(hilf)//'-Current','0.')
    ENDIF
    CoilInfo(iCoil)%LoopNum = GETINT('Coil'//TRIM(hilf)//'-LoopNum','1')
    CoilInfo(iCoil)%NumOfSegments = GETINT('Coil'//TRIM(hilf)//'-NumOfSegments','1')
    ALLOCATE(CoilInfo(iCoil)%SegmentInfo(CoilInfo(iCoil)%NumOfSegments))
    ! Start with 1 Loop Point as zero
    CoilInfo(iCoil)%PointsPerLoop = 1
    DO iSegment = 1,CoilInfo(iCoil)%NumOfSegments
      WRITE(UNIT=hilf2,FMT='(I3)') iSegment
      CoilInfo(iCoil)%SegmentInfo(iSegment)%SegmentType = GETINT('Coil'//TRIM(hilf)//'-Segment'&
                                                          //TRIM(hilf2)//'-SegmentType')
      CoilInfo(iCoil)%SegmentInfo(iSegment)%NumOfPoints = GETINT('Coil'//TRIM(hilf)//&
                                                            '-Segment'//TRIM(hilf2)//'-NumOfPoints',&
                                                            '1')
      ! Add the number of segment points to the total loop points
      ! Attention: Only add the start/endpoint of two adjacent segments only once
      CoilInfo(iCoil)%PointsPerLoop = CoilInfo(iCoil)%PointsPerLoop +&
                                      (CoilInfo(iCoil)%SegmentInfo(iSegment)%NumOfPoints - 1)
      IF (CoilInfo(iCoil)%SegmentInfo(iSegment)%SegmentType.EQ.1) THEN
        CoilInfo(iCoil)%SegmentInfo(iSegment)%LineVector = GETREALARRAY('Coil'//TRIM(hilf)//&
                                                            '-Segment'//TRIM(hilf2)//'-LineVector',2,&
                                                            '0.,0.')
      ELSE IF (CoilInfo(iCoil)%SegmentInfo(iSegment)%SegmentType.EQ.2) THEN
        CoilInfo(iCoil)%SegmentInfo(iSegment)%Radius = GETREAL('Coil'//TRIM(hilf)//&
                                                            '-Segment'//TRIM(hilf2)//'-Radius','0.')
        CoilInfo(iCoil)%SegmentInfo(iSegment)%Phi1       = GETREAL('Coil'//TRIM(hilf)//&
                                                            '-Segment'//TRIM(hilf2)//'-Phi1','0.')/360*2*PI
        CoilInfo(iCoil)%SegmentInfo(iSegment)%Phi2       = GETREAL('Coil'//TRIM(hilf)//&
                                                            '-Segment'//TRIM(hilf2)//'-Phi2','0.')/360*2*PI
      ELSE
        CALL abort(__STAMP__, &
          'No valid segment type defined! Must be either 1 (Line) or 2 (Circle segment)!')
      ENDIF
    ENDDO
    ! Multiply the points per loop with the number of loops in the coil
    ! Attention: Only add the start/endpoint of two adjacent loops only once and don't forget the starting point
    CoilInfo(iCoil)%NumNodes = (CoilInfo(iCoil)%PointsPerLoop - 1) * CoilInfo(iCoil)%LoopNum + 1
  ENDDO
ENDIF
! Iterate over all circle coils
IF (NumOfCircleCoils.GT.0) THEN
  DO iCoil = 1,NumOfCircleCoils
    SWRITE(*,*) "|       Read in Infos of circle coil |", iCoil

    WRITE(UNIT=hilf,FMT='(I3)') iCoil
    CircleCoilInfo(iCoil)%BasePoint(1:3)    = GETREALARRAY('CircleCoil'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    CircleCoilInfo(iCoil)%LengthVector(1:3) = GETREALARRAY('CircleCoil'//TRIM(hilf)//'-LengthVector',3,'0.,0.,0.')
    CircleCoilInfo(iCoil)%Length            = SQRT(CircleCoilInfo(iCoil)%LengthVector(1)**2 +& 
                                              CircleCoilInfo(iCoil)%LengthVector(2)**2 +&
                                              CircleCoilInfo(iCoil)%LengthVector(3)**2)
    CircleCoilInfo(iCoil)%Radius            = GETREAL('CircleCoil'//TRIM(hilf)//'-Radius','0.')
    iCoilTemp = iCoil + NumOfCoils
    TimeDepCoil(iCoilTemp) = GETLOGICAL('CircleCoil'//TRIM(hilf)//'-TimeDepCoil','.FALSE.')
    IF(TimeDepCoil(iCoilTemp)) THEN
      CurrentInfo(iCoilTemp)%CurrentAmpl = GETREAL('CircleCoil'//TRIM(hilf)//'-CurrentAmpl','0.')
      CurrentInfo(iCoilTemp)%CurrentFreq = GETREAL('CircleCoil'//TRIM(hilf)//'-CurrentFreq','0.')
      CurrentInfo(iCoilTemp)%CurrentPhase = GETREAL('CircleCoil'//TRIM(hilf)//'-CurrentPhase','0.')
    ELSE
      CircleCoilInfo(iCoil)%Current = GETREAL('CircleCoil'//TRIM(hilf)//'-Current','0.')
    ENDIF
    CircleCoilInfo(iCoil)%LoopNum           = GETINT('CircleCoil'//TRIM(hilf)//'-LoopNum','1')
    CircleCoilInfo(iCoil)%PointsPerLoop     = GETINT('CircleCoil'//TRIM(hilf)//'-PointsPerLoop','1')
    CircleCoilInfo(iCoil)%NumNodes          = CircleCoilInfo(iCoil)%LoopNum * CircleCoilInfo(iCoil)%PointsPerLoop + 1
  ENDDO
ENDIF
! Iterate over all rectangular coils
IF (NumOfRectangleCoils.GT.0) THEN
  DO iCoil = 1,NumOfRectangleCoils
    SWRITE(*,*) "|       Read in Infos of rectangular coil |", iCoil

    WRITE(UNIT=hilf,FMT='(I3)') iCoil
    RectangleCoilInfo(iCoil)%BasePoint(1:3)    = GETREALARRAY('RectangleCoil'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    RectangleCoilInfo(iCoil)%LengthVector(1:3) = GETREALARRAY('RectangleCoil'//TRIM(hilf)//'-LengthVector',3,'0.,0.,0.')
    RectangleCoilInfo(iCoil)%Length            = SQRT(RectangleCoilInfo(iCoil)%LengthVector(1)**2 +& 
                                                  RectangleCoilInfo(iCoil)%LengthVector(2)**2 +&
                                                  RectangleCoilInfo(iCoil)%LengthVector(3)**2)
    RectangleCoilInfo(iCoil)%AxisVec1          = GETREALARRAY('RectangleCoil'//TRIM(hilf)//'-AxisVec1',3,'0.,0.,0.')
    IF (DOT_PRODUCT(RectangleCoilInfo(iCoil)%LengthVector,RectangleCoilInfo(iCoil)%AxisVec1).NE.0) THEN
      CALL abort(__STAMP__, &
      'ERROR in pic_interpolation.f90: Lenght Vector and Axis Vector of coil need to be orthogonal!',ALLOCSTAT)
    ENDIF
    RectangleCoilInfo(iCoil)%RectVec1          = GETREALARRAY('RectangleCoil'//TRIM(hilf)//'-RectVec1',2,'0.,0.')
    RectangleCoilInfo(iCoil)%RectVec2          = GETREALARRAY('RectangleCoil'//TRIM(hilf)//'-RectVec2',2,'0.,0.')
    iCoilTemp = iCoil + NumOfCoils + NumOfCircleCoils
    TimeDepCoil(iCoilTemp) = GETLOGICAL('RectangleCoil'//TRIM(hilf)//'-TimeDepCoil','.FALSE.')
    IF(TimeDepCoil(iCoilTemp)) THEN
      CurrentInfo(iCoilTemp)%CurrentAmpl = GETREAL('RectangleCoil'//TRIM(hilf)//'-CurrentAmpl','0.')
      CurrentInfo(iCoilTemp)%CurrentFreq = GETREAL('RectangleCoil'//TRIM(hilf)//'-CurrentFreq','0.')
      CurrentInfo(iCoilTemp)%CurrentPhase = GETREAL('RectangleCoil'//TRIM(hilf)//'-CurrentPhase','0.')
    ELSE
      RectangleCoilInfo(iCoil)%Current = GETREAL('RectangleCoil'//TRIM(hilf)//'-Current','0.')
    ENDIF
    RectangleCoilInfo(iCoil)%LoopNum           = GETINT('RectangleCoil'//TRIM(hilf)//'-LoopNum','1')
    RectangleCoilInfo(iCoil)%PointsPerLoop     = GETINT('RectangleCoil'//TRIM(hilf)//'-PointsPerLoop','1')
    IF (MOD(RectangleCoilInfo(iCoil)%PointsPerLoop - 1,4).NE.0) THEN
      RectangleCoilInfo(iCoil)%PointsPerLoop   = RectangleCoilInfo(iCoil)%PointsPerLoop + 4 -&
                                                  MOD(RectangleCoilInfo(iCoil)%PointsPerLoop - 1,4)
    ENDIF
    ! Multiply the points per loop with the number of loops in the coil
    ! Attention: Only add the start/endpoint of two adjacent loops only once and don't forget the starting point
    RectangleCoilInfo(iCoil)%NumNodes = (RectangleCoilInfo(iCoil)%PointsPerLoop - 1) *&
                                          RectangleCoilInfo(iCoil)%LoopNum + 1
  ENDDO
ENDIF
! Iterate over all linear conductors
IF (NumOfLinearConductors.GT.0) THEN
  DO iCoil = 1,NumOfLinearConductors
    SWRITE(*,*) "|      Read in Infos of linear conductor |", iCoil

    WRITE(UNIT=hilf,FMT='(I3)') iCoil
    LinearConductorInfo(iCoil)%BasePoint = GETREALARRAY('LinearConductor'//TRIM(hilf)//'-BasePoint',3,'0.,0.,0.')
    LinearConductorInfo(iCoil)%LengthVector = GETREALARRAY('LinearConductor'//TRIM(hilf)//'-LengthVector',3,'0.,0.,0.')
    iCoilTemp = iCoil + NumOfCoils + NumOfCircleCoils + NumOfRectangleCoils
    TimeDepCoil(iCoilTemp) = GETLOGICAL('LinearConductor'//TRIM(hilf)//'-TimeDepCoil','.FALSE.')
    IF(TimeDepCoil(iCoilTemp)) THEN
      CurrentInfo(iCoilTemp)%CurrentAmpl = GETREAL('LinearConductor'//TRIM(hilf)//'-CurrentAmpl','0.')
      CurrentInfo(iCoilTemp)%CurrentFreq = GETREAL('LinearConductor'//TRIM(hilf)//'-CurrentFreq','0.')
      CurrentInfo(iCoilTemp)%CurrentPhase = GETREAL('LinearConductor'//TRIM(hilf)//'-CurrentPhase','0.')
    ELSE
      LinearConductorInfo(iCoil)%Current = GETREAL('LinearConductor'//TRIM(hilf)//'-Current','0.')
    ENDIF
    LinearConductorInfo(iCoil)%NumNodes = GETINT('LinearConductor'//TRIM(hilf)//'-NumNodes','1')
  ENDDO
ENDIF
! Discretisation in time
IF (ANY(TimeDepCoil)) THEN
  nTimePoints = GETINT('nTimePoints','0')
ENDIF

END SUBROUTINE InitializeSuperB


SUBROUTINE FinalizeSuperB
!===================================================================================================================================
!> 
!===================================================================================================================================
! MODULES
USE MOD_Globals
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================



END SUBROUTINE FinalizeSuperB

END MODULE MOD_SuperB_Init