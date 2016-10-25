#include "boltzplatz.h"

MODULE MOD_Particle_Mesh
!===================================================================================================================================
! Contains global variables provided by the particle surfaces routines
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PUBLIC
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! required variables
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES

INTERFACE InitParticleMesh
  MODULE PROCEDURE InitParticleMesh
END INTERFACE

INTERFACE FinalizeParticleMesh
  MODULE PROCEDURE FinalizeParticleMesh
END INTERFACE

INTERFACE InitFIBGM
  MODULE PROCEDURE InitFIBGM
END INTERFACE

INTERFACE InitSFIBGM
  MODULE PROCEDURE InitSFIBGM
END INTERFACE

INTERFACE SingleParticleToExactElement
  MODULE PROCEDURE SingleParticleToExactElement
END INTERFACE

INTERFACE SingleParticleToExactElementNoMap
  MODULE PROCEDURE SingleParticleToExactElementNoMap
END INTERFACE

INTERFACE InitElemVolumes
  MODULE PROCEDURE InitElemVolumes
END INTERFACE

INTERFACE MapRegionToElem
  MODULE PROCEDURE MapRegionToElem
END INTERFACE

INTERFACE PointToExactElement
  MODULE PROCEDURE PointToExactElement
END INTERFACE

INTERFACE BuildElementBasis
  MODULE PROCEDURE BuildElementBasis
END INTERFACE

INTERFACE BuildElementOrigin
  MODULE PROCEDURE BuildElementOrigin
END INTERFACE

INTERFACE CountPartsPerElem
  MODULE PROCEDURE CountPartsPerElem
END INTERFACE

!INTERFACE CheckIfCurvedElem
!  MODULE PROCEDURE CheckIfCurvedElem
!END INTERFACE

INTERFACE InitElemBoundingBox
  MODULE PROCEDURE InitElemBoundingBox
END INTERFACE

INTERFACE InsideElemBoundingBox
  MODULE PROCEDURE InsideElemBoundingBox
END INTERFACE

INTERFACE GetElemAndSideType
  MODULE PROCEDURE GetElemAndSideType
END INTERFACE

INTERFACE PartInElemCheck
  MODULE PROCEDURE PartInElemCheck
END INTERFACE


PUBLIC::CountPartsPerElem
PUBLIC::BuildElementBasis,CheckIfCurvedElem,BuildElementOrigin
PUBLIC::InitElemVolumes,MapRegionToElem,PointToExactElement
PUBLIC::InitParticleMesh,FinalizeParticleMesh, InitFIBGM,InitSFIBGM, SingleParticleToExactElement, SingleParticleToExactElementNoMap
PUBLIC::InsideElemBoundingBox
PUBLIC::PartInElemCheck
!===================================================================================================================================
!
CONTAINS

SUBROUTINE InitParticleMesh()
!===================================================================================================================================
! Init of Particle mesh
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Mesh_Vars
USE MOD_Particle_Surfaces_Vars, ONLY:BezierEpsilonBilinear,BezierElevation,BezierControlPoints3DElevated
USE MOD_Particle_Tracking_Vars, ONLY:DoRefMapping,MeasureTrackTime,FastPeriodic,CountNbOfLostParts,nLostParts
USE MOD_Mesh_Vars,              ONLY:nElems,nSides,SideToElem,ElemToSide,NGeo,NGeoElevated
USE MOD_ReadInTools,            ONLY:GETREAL,GETINT,GETLOGICAL,GetRealArray
USE MOD_Particle_Surfaces_Vars, ONLY:BezierSampleN,BezierSampleXi
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: ALLOCSTAT
INTEGER           :: iElem, ilocSide,SideID,flip,iSide,iSample
CHARACTER(LEN=2)  :: hilf
!===================================================================================================================================

SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLE MESH ...'
IF(ParticleMeshInitIsDone) CALL abort(&
__STAMP__&
, ' Particle-Mesh is already initialized.')
! allocate and duplicate partElemToside
nTotalSides=nSides
nTotalBCSides=nSides
nTotalElems=nElems
ALLOCATE(PartElemToSide(1:2,1:6,1:nTotalSides)    &
        ,PartSideToElem(1:5,1:nTotalSides)        &
        ,PartElemToElem(1:2,1:6,1:nTotalElems)    &
        ,STAT=ALLOCSTAT                      )
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__&
,'  Cannot allocate particle mesh vars!')


DoRefMapping       = GETLOGICAL('DoRefMapping',".TRUE.")
CountNbOfLostParts = GETLOGICAL('CountNbOfLostParts',".FALSE.")
nLostParts         = 0 

!IF(.NOT.DoRefMapping) THEN
!  SDEALLOCATE(nTracksPerElem)
!END IF
MeasureTrackTime = GETLOGICAL('MeasureTrackTime','.FALSE.')
FastPeriodic = GETLOGICAL('FastPeriodic','.FALSE.')

! method from xPhysic to parameter space
RefMappingGuess = GETINT('RefMappingGuess','1')
RefMappingEps   = GETREAL('RefMappingEps','1e-4')

epsInCell       = SQRT(3.0*RefMappingEps)
!epsOneCell      = 1.0+epsInCell

IF((RefMappingGuess.LT.1).OR.(RefMappingGuess.GT.4))THEN
   CALL abort(&
__STAMP__ &
,'Wrong guessing method for mapping from physical space in reference space.',RefMappingGuess,999.)
END IF
IF(DoRefMapping .AND. RefMappingGuess.EQ.2) THEN
   CALL abort(&
__STAMP__ &
,' No-Elem_xGP allocated for Halo-Cells! Select other mapping guess',RefMappingGuess)
END IF

BezierEpsilonBilinear = GETREAL('BezierEpsilonBilinear','1e-6')

BezierElevation = GETINT('BezierElevation','0')
NGeoElevated    = NGeo + BezierElevation
SDEALLOCATE(BezierControlPoints3DElevated)
ALLOCATE(BezierControlPoints3DElevated(1:3,0:NGeo+BezierElevation,0:NGeo+BezierElevation,1:nSides) &
        ,STAT=ALLOCSTAT )
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__&
,'  Cannot allocate BezierControlPoints3DElevated!')
BezierControlPoints3DElevated=0.

! BezierAreaSample stuff:
WRITE( hilf, '(I2.2)') NGeo
BezierSampleN = GETINT('BezierSampleN',hilf)
ALLOCATE(BezierSampleXi(0:BezierSampleN))!,STAT=ALLOCSTAT)
DO iSample=0,BezierSampleN
  BezierSampleXi(iSample)=-1.+2.0/BezierSampleN*iSample
END DO

!--- Initialize Periodic Side Info
!ALLOCATE(SidePeriodicType(1:nSides)) 
!SidePeriodicType=0
!DO iElem=1,nElems
!  DO iLocSide=1,6
!    SideID = ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
!    IF ((Elems(iElem+offsetElem)%ep%Side(iLocSide)%sp%BCindex.GT.0)           .AND. &
!        (ASSOCIATED(Elems(iElem+offsetElem)%ep%Side(iLocSide)%sp%connection))) THEN
!      SidePeriodicType(SideID) = -1
!    END IF
!  END DO
!END DO

! copy
DO iElem=1,PP_nElems
  DO iLocSide=1,6
    PartElemToSide(:,iLocSide,iElem)=ElemToSide(:,iLocSide,iElem)
  END DO 
END DO
DO iSide=1,nSides
  PartSideToElem(:,iSide)=SideToElem(:,iSide)
END DO 

! get conection
DO iElem=1,PP_nElems
  DO ilocSide=1,6
    flip = ElemToSide(E2S_FLIP,ilocSide,iElem)
    SideID = ElemToSide(E2S_SIDE_ID,ilocSide,iElem)
    IF(flip.EQ.0)THEN
      ! SideID of slave
      PartElemToElem(E2E_NB_LOC_SIDE_ID,ilocSide,iElem)=SideToElem(S2E_NB_LOC_SIDE_ID,SideID)
      PartElemToElem(E2E_NB_ELEM_ID,ilocSide,iElem)=SideToElem(S2E_NB_ELEM_ID,SideID)
    ELSE
      ! SideID of master
      PartElemToElem(E2E_NB_LOC_SIDE_ID,ilocSide,iElem)=SideToElem(S2E_LOC_SIDE_ID,SideID)
      PartElemToElem(E2E_NB_ELEM_ID,ilocSide,iElem)=SideToElem(S2E_ELEM_ID,SideID)
    END IF
  END DO ! ilocSide
END DO ! Elem

ParticleMeshInitIsDone=.TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLE MESH DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')

END SUBROUTINE InitParticleMesh


SUBROUTINE FinalizeParticleMesh()
!===================================================================================================================================
! read required parameters
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Particle_Mesh_Vars
USE MOD_Particle_Tracking_Vars, ONLY: Distance,ListDistance
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================

SDEALLOCATE(PartElemToSide)
SDEALLOCATE(PartSideToElem)
SDEALLOCATE(PartElemToElem)
SDEALLOCATE(PartBCSideList)
SDEALLOCATE(SidePeriodicType)
SDEALLOCATE(SidePeriodicDisplacement)
SDEALLOCATE(IsBCElem)
SDEALLOCATE(GEO%PeriodicVectors)
SDEALLOCATE(GEO%FIBGM)
SDEALLOCATE(GEO%Volume)
SDEALLOCATE(GEO%DeltaEvMPF)
SDEALLOCATE(GEO%ElemToFIBGM)
SDEALLOCATE(BCElem)
SDEALLOCATE(XiEtaZetaBasis)
SDEALLOCATE(slenXiEtaZetaBasis)
SDEALLOCATE(ElemBaryNGeo)
SDEALLOCATE(ElemRadiusNGeo)
SDEALLOCATE(ElemRadius2NGeo)
SDEALLOCATE(EpsOneCell)
SDEALLOCATE(Distance)
SDEALLOCATE(ListDistance)

ParticleMeshInitIsDone=.FALSE.

END SUBROUTINE FinalizeParticleMesh


SUBROUTINE SingleParticleToExactElement(iPart,doHalo)                                                         
!===================================================================================================================================
! this subroutine maps each particle to an element
! currently, a background mesh is used to find possible elements. if multiple elements are possible, the element with the smallest
! distance is picked as an initial guess
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Vars,          ONLY:PartState,PEM,PDM,PartPosRef
USE MOD_Particle_Mesh_Vars,     ONLY:Geo
USE MOD_Particle_Tracking_Vars, ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,     ONLY:epsOneCell,ElemBaryNGeo,IsBCElem,ElemRadius2NGeo
USE MOD_Eval_xyz,               ONLY:eval_xyz_elemcheck
USE MOD_Utils,                  ONLY:InsertionSort !BubbleSortID
USE MOD_Particle_Tracking_Vars, ONLY:DoRefMapping,Distance,ListDistance
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE                                                                                   
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
INTEGER,INTENT(IN)                :: iPart
LOGICAL,INTENT(IN)                :: doHalo
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                           :: iBGMElem,nBGMElems, ElemID, CellX,CellY,CellZ
!-----------------------------------------------------------------------------------------------------------------------------------
LOGICAL                           :: InElementCheck,ParticleFound                                
REAL                              :: xi(1:3),Distance2
!===================================================================================================================================

!epsOne=1.0+epsInCell
!OneMeps=1.0-eps
ParticleFound = .FALSE.
IF ( (PartState(iPart,1).LT.GEO%xmin).OR.(PartState(iPart,1).GT.GEO%xmax).OR. &
     (PartState(iPart,2).LT.GEO%ymin).OR.(PartState(iPart,2).GT.GEO%ymax).OR. &
     (PartState(iPart,3).LT.GEO%zmin).OR.(PartState(iPart,3).GT.GEO%zmax)) THEN
   PDM%ParticleInside(iPart) = .FALSE.
   RETURN
END IF

! --- get background mesh cell of particle
CellX = CEILING((PartState(iPart,1)-GEO%xminglob)/GEO%FIBGMdeltas(1)) 
CellX = MAX(MIN(GEO%TFIBGMimax,CellX),GEO%TFIBGMimin)
CellY = CEILING((PartState(iPart,2)-GEO%yminglob)/GEO%FIBGMdeltas(2))
CellY = MAX(MIN(GEO%TFIBGMjmax,CellY),GEO%TFIBGMjmin)
CellZ = CEILING((PartState(iPart,3)-GEO%zminglob)/GEO%FIBGMdeltas(3))
CellZ = MAX(MIN(GEO%TFIBGMkmax,CellZ),GEO%TFIBGMkmin)

!--- check all cells associated with this beckground mesh cell
nBGMElems=GEO%TFIBGM(CellX,CellY,CellZ)%nElem

! get closest element barycenter
Distance=-1.
ListDistance=0
DO iBGMElem = 1, nBGMElems
  ElemID = GEO%TFIBGM(CellX,CellY,CellZ)%Element(iBGMElem)
  Distance2=(PartState(iPart,1)-ElemBaryNGeo(1,ElemID))*(PartState(iPart,1)-ElemBaryNGeo(1,ElemID)) &
           +(PartState(iPart,2)-ElemBaryNGeo(2,ElemID))*(PartState(iPart,2)-ElemBaryNGeo(2,ElemID)) &
           +(PartState(iPart,3)-ElemBaryNGeo(3,ElemID))*(PartState(iPart,3)-ElemBaryNGeo(3,ElemID)) 
  IF(Distance2.GT.ElemRadius2NGeo(ElemID))THEN
    Distance(iBGMElem)=-1.
  ELSE
    Distance(iBGMElem)=Distance2
  END IF
  ListDistance(iBGMElem)=ElemID
END DO ! nBGMElems

IF(ALMOSTEQUAL(MAXVAL(Distance),-1.))THEN
  PDM%ParticleInside(iPart) = .FALSE.
  RETURN
END IF

!CALL BubbleSortID(Distance,ListDistance,nBGMElems)
IF(nBGMElems.GT.1) CALL InsertionSort(Distance(1:nBGMElems),ListDistance(1:nBGMElems),nBGMElems)

! loop through sorted list and start by closest element  
DO iBGMElem=1,nBGMElems
  IF(ALMOSTEQUAL(Distance(iBGMElem),-1.))CYCLE
  ElemID=ListDistance(iBGMElem)
  IF(.NOT.DoHALO)THEN
    IF(ElemID.GT.PP_nElems) CYCLE
  END IF
  IF(IsBCElem(ElemID))THEN
    CALL PartInElemCheck(PartState(iPart,1:3),iPart,ElemID,InElementCheck)
    IF(.NOT.InElementCheck) CYCLE
  END IF

  CALL Eval_xyz_elemcheck(PartState(iPart,1:3),xi,ElemID)
  IF(MAXVAL(ABS(Xi)).LT.epsOneCell(ElemID))THEN ! particle outside
    InElementCheck=.TRUE.
  ELSE ! particle at face,edge or node, check most possible point
    InElementCheck=.FALSE.
  END IF
  IF (InElementCheck) THEN !  !     print*,Element
 ! read*
    PEM%Element(iPart) = ElemID
    IF(DoRefMapping) PartPosRef(1:3,iPart) = Xi
    ParticleFound = .TRUE.
    EXIT
  END IF
END DO ! iBGMElem

! particle not found
IF (.NOT.ParticleFound) THEN
  PDM%ParticleInside(iPart) = .FALSE.
END IF
END SUBROUTINE SingleParticleToExactElement


SUBROUTINE SingleParticleToExactElementNoMap(iPart,doHALO)
!===================================================================================================================================
! this subroutine maps each particle to an element
! currently, a background mesh is used to find possible elements. if multiple elements are possible, the element with the smallest
! distance is picked as an initial guess
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Mesh_Vars,              ONLY:NGeo
USE MOD_Particle_Vars,          ONLY:PartState,PEM,PDM,LastPartPos
USE MOD_Particle_Mesh_Vars,     ONLY:PartElemToSide,ElemBaryNGeo,ElemRadius2NGeo
USE MOD_Particle_Mesh_Vars,     ONLY:Geo
USE MOD_Particle_Surfaces_Vars, ONLY:epsilontol,BezierControlPoints3D,SideType
USE MOD_Utils,                  ONLY:InsertionSort !BubbleSortID
USE MOD_Particle_Tracking_Vars, ONLY:Distance,ListDistance
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE                                                                                   
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
INTEGER,INTENT(IN)                :: iPart
LOGICAL,INTENT(IN)                :: doHalo
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                           :: iBGMElem,nBGMElems, ElemID, CellX,CellY,CellZ
!-----------------------------------------------------------------------------------------------------------------------------------
INTEGER                           :: ilocSide,SideID,flip
LOGICAL                           :: ParticleFound,InElementCheck
REAL                              :: Distance2
!===================================================================================================================================

ParticleFound = .FALSE.
IF ( (PartState(iPart,1).LT.GEO%xmin).OR.(PartState(iPart,1).GT.GEO%xmax).OR. &
     (PartState(iPart,2).LT.GEO%ymin).OR.(PartState(iPart,2).GT.GEO%ymax).OR. &
     (PartState(iPart,3).LT.GEO%zmin).OR.(PartState(iPart,3).GT.GEO%zmax)) THEN
   PDM%ParticleInside(iPart) = .FALSE.
   RETURN
END IF

! --- get background mesh cell of particle
CellX = CEILING((PartState(iPart,1)-GEO%xminglob)/GEO%FIBGMdeltas(1)) 
CellX = MAX(MIN(GEO%TFIBGMimax,CellX),GEO%TFIBGMimin)
CellY = CEILING((PartState(iPart,2)-GEO%yminglob)/GEO%FIBGMdeltas(2))
CellY = MAX(MIN(GEO%TFIBGMjmax,CellY),GEO%TFIBGMjmin)
CellZ = CEILING((PartState(iPart,3)-GEO%zminglob)/GEO%FIBGMdeltas(3))
CellZ = MAX(MIN(GEO%TFIBGMkmax,CellZ),GEO%TFIBGMkmin)

!--- check all cells associated with this beckground mesh cell

nBGMElems=GEO%TFIBGM(CellX,CellY,CellZ)%nElem


! get closest element barycenter
Distance=-1.

ListDistance=0
DO iBGMElem = 1, nBGMElems
  ElemID = GEO%TFIBGM(CellX,CellY,CellZ)%Element(iBGMElem)
  IF(.NOT.DoHALO)THEN
    IF(ElemID.GT.PP_nElems) CYCLE
  END IF
  Distance2=(PartState(iPart,1)-ElemBaryNGeo(1,ElemID))*(PartState(iPart,1)-ElemBaryNGeo(1,ElemID)) &
           +(PartState(iPart,2)-ElemBaryNGeo(2,ElemID))*(PartState(iPart,2)-ElemBaryNGeo(2,ElemID)) &
           +(PartState(iPart,3)-ElemBaryNGeo(3,ElemID))*(PartState(iPart,3)-ElemBaryNGeo(3,ElemID)) 
  IF(Distance2.GT.ElemRadius2NGeo(ElemID))THEN
    Distance(iBGMElem)=-1.
  ELSE
    Distance(iBGMElem)=Distance2
  END IF
  ListDistance(iBGMElem)=ElemID
END DO ! nBGMElems

IF(ALMOSTEQUAL(MAXVAL(Distance),-1.))THEN
  PDM%ParticleInside(iPart) = .FALSE.
  RETURN
END IF

!CALL BubbleSortID(Distance,ListDistance,nBGMElems)
IF(nBGMElems.GT.1) CALL InsertionSort(Distance(1:nBGMElems),ListDistance(1:nBGMElems),nBGMElems)
! loop through sorted list and start by closest element  

DO iBGMElem=1,nBGMElems
  IF(ALMOSTEQUAL(Distance(iBGMElem),-1.))CYCLE
  ElemID=ListDistance(iBGMElem)
  IF(.NOT.DoHALO)THEN
    IF(ElemID.GT.PP_nElems) CYCLE
  END IF
  CALL PartInElemCheck(PartState(iPart,1:3),iPart,ElemID,InElementCheck)

  IF(InElementCheck)THEN
    ! no intersection found and particle is in final element
    PEM%Element(iPart) = ElemID
    ParticleFound=.TRUE.
    EXIT
  END IF
END DO ! iBGMElem

! particle not found
IF (.NOT.ParticleFound) THEN
  PDM%ParticleInside(iPart) = .FALSE.
END IF
END SUBROUTINE SingleParticleToExactElementNoMap


SUBROUTINE PartInElemCheck(PartPos_In,PartID,ElemID,Check)
!===================================================================================================================================
! Checks if particle is in Element
!===================================================================================================================================
! MODULES
USE MOD_Globals,                ONLY:Almostzero
USE MOD_Mesh_Vars,              ONLY:NGeo
USE MOD_Particle_Mesh_Vars,     ONLY:ElemBaryNGeo
USE MOD_Particle_Surfaces_Vars, ONLY:BezierControlPoints3D,SideType,BezierControlPoints3D,SideNormVec
USE MOD_Particle_Mesh_Vars,     ONLY:PartElemToSide,PartBCSideList
USE MOD_Particle_Surfaces,      ONLY:CalcNormAndTangBilinear,CalcNormAndTangBezier
USE MOD_Particle_Intersection,  ONLY:ComputePlanarRectIntersection
USE MOD_Particle_Intersection,  ONLY:ComputePlanarNonrectIntersection
USE MOD_Particle_Intersection,  ONLY:ComputeBiLinearIntersection
USE MOD_Particle_Intersection,  ONLY:ComputeCurvedIntersection
USE MOD_Particle_Tracking_Vars, ONLY:DoRefMapping
USE MOD_Particle_Vars,          ONLY:PartState,LastPartPos
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN)                       :: ElemID,PartID
REAL,INTENT(IN)                          :: PartPos_In(1:3)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
LOGICAL,INTENT(OUT)                      :: Check
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                                  :: ilocSide,flip,SideID,BCSideID
REAL                                     :: PartTrajectory(1:3),NormVec(1:3)
REAL                                     :: lengthPartTrajectory,PartPos(1:3),LastPosTmp(1:3),xNodes(1:3,1:4)
LOGICAL                                  :: isHit
REAL                                     :: alpha,eta,xi
!===================================================================================================================================

! virtual move to element barycenter
LastPosTmp(1:3) =LastPartPos(PartID,1:3)
LastPartPos(PartID,1:3) =ElemBaryNGeo(1:3,ElemID)
PartPos(1:3) =PartPos_In(1:3)
PartTrajectory=PartPos - LastPartPos(PartID,1:3)
lengthPartTrajectory=SQRT(PartTrajectory(1)*PartTrajectory(1) &
                         +PartTrajectory(2)*PartTrajectory(2) &
                         +PartTrajectory(3)*PartTrajectory(3) )
IF(ALMOSTZERO(lengthPartTrajectory))THEN
  Check=.TRUE.
  LastPartPos(PartID,1:3) = LastPosTmp(1:3) 
  ! bugfix by Tilman
  RETURN
END IF
PartTrajectory=PartTrajectory/lengthPartTrajectory
isHit=.FALSE.
DO ilocSide=1,6
  !SideID=ElemToSide(E2S_SIDE_ID,ilocSide,ElemID) 
  SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,ElemID) 
  flip  = PartElemToSide(E2S_FLIP,ilocSide,ElemID)
  IF(DoRefMapping)THEN
    IF(SideID.LT.1) CYCLE
    BCSideID=SideID
    SideID=PartBCSideList(BCSideID)
    IF(SideID.LT.1) CYCLE
  END IF
  
  SELECT CASE(SideType(SideID))
  CASE(PLANAR_RECT)
    CALL ComputePlanarRectIntersection(ishit,PartTrajectory,lengthPartTrajectory,alpha,xi,eta ,PartID,flip,SideID)
  !CASE(PLANAR_NONRECT)
  !  CALL ComputePlanarNonrectIntersection(isHit,PartTrajectory,lengthPartTrajectory,Alpha,xi,eta,PartID,flip,SideID)
  CASE(BILINEAR,PLANAR_NONRECT)
    xNodes(1:3,1)=BezierControlPoints3D(1:3,0   ,0   ,SideID)
    xNodes(1:3,2)=BezierControlPoints3D(1:3,NGeo,0   ,SideID)
    xNodes(1:3,3)=BezierControlPoints3D(1:3,NGeo,NGeo,SideID)
    xNodes(1:3,4)=BezierControlPoints3D(1:3,0   ,NGeo,SideID)
    CALL ComputeBiLinearIntersection(isHit,xNodes,PartTrajectory,lengthPartTrajectory,Alpha,xi,eta,PartID,flip,SideID)
  CASE(CURVED,PLANAR_CURVED)
    CALL ComputeCurvedIntersection(isHit,PartTrajectory,lengthPartTrajectory,Alpha,xi,eta,PartID,SideID)
  END SELECT
  IF(DoRefMapping)THEN
    IF(alpha.GT.-1)THEN
      SELECT CASE(SideType(SideID))
      CASE(PLANAR_RECT,PLANAR_NONRECT,PLANAR_CURVED)
        NormVec=SideNormVec(1:3,SideID)
      CASE(BILINEAR)
        CALL CalcNormAndTangBilinear(nVec=NormVec,xi=xi,eta=eta,SideID=SideID)
      CASE(CURVED)
        CALL CalcNormAndTangBezier(nVec=NormVec,xi=xi,eta=eta,SideID=SideID)
      END SELECT 
      IF(DOT_PRODUCT(NormVec,PartState(PartID,4:6)).LT.0.) alpha=-1.0
    END IF
  END IF
  IF(alpha.GT.-1.0) THEN
    !IF((ABS(xi).GT.1.0).OR.(ABS(eta).GT.1.0)) THEN
    !IF((ABS(xi).GT.BezierClipHit).OR.(ABS(eta).GT.BezierClipHit)) THEN
    !  isHit=.FALSE.
    !END IF
    isHit=.TRUE.
  END IF
  IF(isHit) EXIT
END DO ! ilocSide
Check=.TRUE.
IF(isHit) Check=.FALSE.
LastPartPos(PartID,1:3) = LastPosTmp(1:3) 

END SUBROUTINE PartInElemCheck


SUBROUTINE InitSFIBGM()
!===================================================================================================================================
! Build Fast-Init-Background-Mesh.
! The BGM is a cartesian mesh for easier locating of particles
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_ReadInTools,                        ONLY:GetRealArray,GetLogical
!USE MOD_Particle_Surfaces,                  ONLY:GetSideType,GetBCSideType!,BuildElementBasis
USE MOD_Particle_Tracking_Vars,             ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems
USE MOD_Particle_Mesh_Vars,                 ONLY:XiEtaZetaBasis,ElemBaryNGeo,slenXiEtaZetaBasis,ElemRadiusNGeo,ElemRadius2NGeo
#ifdef MPI
USE MOD_Particle_MPI,                       ONLY:InitSimpleHALOMesh
USE MOD_Particle_MPI,                       ONLY:InitHALOMesh
USE MOD_Particle_MPI_Vars,                  ONLY:printMPINeighborWarnings
#endif /*MPI*/
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: StartT,EndT
!=================================================================================================================================

!! Read parameter for FastInitBackgroundMesh (FIBGM)
GEO%FIBGMdeltas(1:3) = GETREALARRAY('Part-FIBGMdeltas',3,'1. , 1. , 1.')
GEO%FactorFIBGM(1:3) = GETREALARRAY('Part-FactorFIBGM',3,'1. , 1. , 1.')
GEO%FIBGMdeltas(1:3) = 1./GEO%FactorFIBGM(1:3) * GEO%FIBGMdeltas(1:3)

! simplified halo region
! compute elem bary and elem radius
StartT=BOLTZPLATZTIME()
ALLOCATE(ElemBaryNGeo(1:3,1:nTotalElems) )
CALL BuildElementOrigin()
ALLOCATE(XiEtaZetaBasis(1:3,1:6,1:nTotalElems) &
        ,slenXiEtaZetaBasis(1:6,1:nTotalElems) &
        ,ElemRadiusNGeo(1:nTotalElems)         &
        ,ElemRadius2NGeo(1:nTotalElems)        )
CALL BuildElementBasis()
EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
  WRITE(UNIT_stdOut,'(A,F12.3,A)',ADVANCE='YES')' Init element-basis took          [',EndT-StartT,'s]'
END IF

StartT=BOLTZPLATZTIME()
CALL GetSFIBGM()
EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
  WRITE(UNIT_stdOut,'(A,F12.3,A)',ADVANCE='YES')' Init FIBGM took                  [',EndT-StartT,'s]'
END IF

#ifdef MPI
SWRITE(UNIT_stdOut,'(A)')' INIT HALO REGION...' 
StartT=BOLTZPLATZTIME()
!CALL Initialize()  ! Initialize parallel environment for particle exchange between MPI domains
printMPINeighborWarnings = GETLOGICAL('printMPINeighborWarnings','.TRUE.')
CALL InitSimpleHaloMesh()
#else
StartT=BOLTZPLATZTIME()
#endif /*MPI*/

! remove inner BezierControlPoints3D and SlabNormals, usw.
IF(DoRefMapping) CALL ReshapeBezierSides()

CALL GetElemAndSideType() 

SDEALLOCATE(XiEtaZetaBasis)
SDEALLOCATE(slenXiEtaZetaBasis)
SDEALLOCATE(ElemRadiusNGeo)
SDEALLOCATE(ElemRadius2NGeo)

ALLOCATE(XiEtaZetaBasis(1:3,1:6,1:nTotalElems) &
        ,slenXiEtaZetaBasis(1:6,1:nTotalElems) &
        ,ElemRadiusNGeo(1:nTotalElems)         &
        ,ElemRadius2NGeo(1:nTotalElems)        )
CALL BuildElementBasis()


! HALO mesh and region build. Unfortunately, the local FIBGM has to be extended to include the HALO elements :(
! rebuild is a local operation
CALL AddSimpleHALOCellsToFIBGM()
EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
   WRITE(UNIT_stdOut,'(A,F12.3,A)',ADVANCE='YES')' Construction of halo region took [',EndT-StartT,'s]'
END IF

!CALL MapElemToFIBGM()

SWRITE(UNIT_stdOut,'(A)')' DONE!' 

END SUBROUTINE InitSFIBGM


SUBROUTINE InitFIBGM()
!===================================================================================================================================
! Build Fast-Init-Background-Mesh.
! The BGM is a cartesian mesh for easier locating of particles
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_ReadInTools,                        ONLY:GetRealArray,GetLogical
!USE MOD_Particle_Surfaces,                  ONLY:GetSideType,GetBCSideType!,BuildElementBasis
USE MOD_Particle_Tracking_Vars,             ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems
USE MOD_Particle_Mesh_Vars,                 ONLY:XiEtaZetaBasis,ElemBaryNGeo,slenXiEtaZetaBasis,ElemRadiusNGeo,ElemRadius2NGeo
#ifdef MPI
USE MOD_Particle_MPI,                       ONLY:InitHALOMesh
USE MOD_Particle_MPI_Vars,                  ONLY:printMPINeighborWarnings
#endif /*MPI*/
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: StartT,EndT
INTEGER                  :: iElem,ElemToBGM(1:6,1:PP_nElems)
INTEGER,ALLOCATABLE      :: HaloElemToBGM(:,:)
!=================================================================================================================================

!! Read parameter for FastInitBackgroundMesh (FIBGM)
GEO%FIBGMdeltas(1:3) = GETREALARRAY('Part-FIBGMdeltas',3,'1. , 1. , 1.')
GEO%FactorFIBGM(1:3) = GETREALARRAY('Part-FactorFIBGM',3,'1. , 1. , 1.')
GEO%FIBGMdeltas(1:3) = 1./GEO%FactorFIBGM(1:3) * GEO%FIBGMdeltas(1:3)

! compute elem bary and elem radius
StartT=BOLTZPLATZTIME()
ALLOCATE(ElemBaryNGeo(1:3,1:nTotalElems) )
CALL BuildElementOrigin()
ALLOCATE(XiEtaZetaBasis(1:3,1:6,1:nTotalElems) &
        ,slenXiEtaZetaBasis(1:6,1:nTotalElems) &
        ,ElemRadiusNGeo(1:nTotalElems)         &
        ,ElemRadius2NGeo(1:nTotalElems)        )
CALL BuildElementBasis()
EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
  WRITE(UNIT_stdOut,'(A,F12.3,A)',ADVANCE='YES')' Init element-basis took          [',EndT-StartT,'s]'
END IF

StartT=BOLTZPLATZTIME()
! get new min max
CALL GetFIBGMminmax()
! sort elem in bgm cells
DO iElem=1,PP_nElems
  CALL BGMIndexOfElement(iElem,ElemToBGM(1:6,iElem)) 
END DO ! iElem = nElems+1,nTotalElems
CALL GetFIBGM(ElemToBGM)
EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
  WRITE(UNIT_stdOut,'(A,F12.3,A)',ADVANCE='YES')' Init FIBGM took                  [',EndT-StartT,'s]'
END IF

StartT=BOLTZPLATZTIME()
#ifdef MPI
SWRITE(UNIT_stdOut,'(A)')' INIT HALO REGION...' 
!CALL Initialize()  ! Initialize parallel environment for particle exchange between MPI domains
printMPINeighborWarnings = GETLOGICAL('printMPINeighborWarnings','.TRUE.')
CALL InitHaloMesh()
! HALO mesh and region build. Unfortunately, the local FIBGM has to be extended to include the HALO elements :(
! rebuild is a local operation
#endif /*MPI*/

IF(nTotalElems.GT.PP_nElems)THEN
  ALLOCATE(HaloElemToBGM(1:6,PP_nElems+1:nTotalElems))
  DO iElem=PP_nElems+1,nTotalElems
    CALL BGMIndexOfElement(iElem,HaloElemToBGM(1:6,iElem)) 
  END DO ! iElem = nElems+1,nTotalElems
  CALL AddHALOCellsToFIBGM(ElemToBGM,HaloElemToBGM)
  DEALLOCATE(HaloElemToBGM)
ELSE
  CALL AddHALOCellsToFIBGM(ElemToBGM)
END IF


EndT=BOLTZPLATZTIME()
IF(PartMPI%MPIROOT)THEN
   WRITE(UNIT_stdOut,'(A,F8.3,A)',ADVANCE='YES')' Construction of halo region took [',EndT-StartT,'s]'
END IF

! remove inner BezierControlPoints3D and SlabNormals, usw.
IF(DoRefMapping) CALL ReshapeBezierSides()


CALL GetElemAndSideType() 
!! sort element faces by type - linear, bilinear, curved
!IF(DoRefMapping) THEN !  CALL GetBCSideType()
!ELSE
!  CALL GetSideType()
!END IF

SDEALLOCATE(XiEtaZetaBasis)
SDEALLOCATE(slenXiEtaZetaBasis)
SDEALLOCATE(ElemRadiusNGeo)
SDEALLOCATE(ElemRadius2NGeo)
ALLOCATE(XiEtaZetaBasis(1:3,1:6,1:nTotalElems) &
        ,slenXiEtaZetaBasis(1:6,1:nTotalElems) &
        ,ElemRadiusNGeo(1:nTotalElems)         &
        ,ElemRadius2NGeo(1:nTotalElems)        )
CALL BuildElementBasis()

SWRITE(UNIT_stdOut,'(A)')' DONE!' 

END SUBROUTINE InitFIBGM


SUBROUTINE GetFIBGM(ElemToBGM)
!===================================================================================================================================
! build local FIBGM mesh for process local FIBGM mesh including HALO region
! mode 1: build local BGM and interconnections with other processes
! mode 2: rebuild BGM including HALO region
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals!,            ONLY : UNIT_StdOut
USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D,sVdm_Bezier
USE MOD_Mesh_Vars,                          ONLY:XCL_NGeo
USE MOD_Mesh_Vars,                          ONLY:NGeo
USE MOD_Partilce_Periodic_BC,               ONLY:InitPeriodicBC
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems,nTotalSides
USE MOD_PICDepo,                            ONLY:InitializeDeposition
USE MOD_Particle_MPI_Vars,                  ONLY:SafetyFactor,halo_eps_velo,halo_eps,halo_eps2
#ifndef PP_HDG
USE MOD_CalcTimeStep,                       ONLY:CalcTimeStep
#endif /*PP_HDG*/
USE MOD_Equation_Vars,                      ONLY:c
USE MOD_Particle_Vars,                      ONLY:manualtimestep
#if (PP_TimeDiscMethod==201)
USE MOD_Particle_Vars,                      ONLY:dt_part_ratio
#endif
USE MOD_Particle_Mesh_Vars,                 ONLY:PartElemToSide
USE MOD_ChangeBasis,                        ONLY:ChangeBasis2D
#ifdef MPI
USE MOD_Particle_MPI,                       ONLY:InitHALOMesh
USE MOD_Particle_Mesh_Vars,                 ONLY:FIBGMCellPadding
USE MOD_PICDepo_Vars,                       ONLY:DepositionType, r_sf
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
USE MOD_Particle_Mesh_Vars,                 ONLY:NbrOfCases,casematrix
#endif /*MPI*/

! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!INTEGER,INTENT(IN)    :: mode
INTEGER,INTENT(IN)     :: ElemToBGM(1:6,1:PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!REAL                  :: localXmin,localXmax,localymin,localymax,localzmin,localzmax
INTEGER                          :: BGMimin,BGMimax,BGMjmin,BGMjmax,BGMkmin,BGMkmax
!REAL                             :: xmin, xmax, ymin, ymax, zmin, zmax
INTEGER                          :: iBGM,jBGM,kBGM,iElem,ilocSide,iSide,SideID
INTEGER                          :: BGMCellXmax,BGMCellXmin
INTEGER                          :: BGMCellYmax,BGMCellYmin
INTEGER                          :: BGMCellZmax,BGMCellZmin
INTEGER                          :: ALLOCSTAT
INTEGER                          :: iProc
REAL                             :: deltaT
REAL                             :: BezierControlPoints3D_tmp(1:3,0:NGeo,0:NGeo)
#ifdef MPI
INTEGER                          :: ii,jj,kk,i,j
INTEGER                          :: BGMCells,  m, CurrentProc, Cell, Procs
INTEGER                          :: imin, imax, kmin, kmax, jmin, jmax
INTEGER                          :: nPaddingCellsX, nPaddingCellsY, nPaddingCellsZ
INTEGER                          :: nShapePaddingX, nShapePaddingY, nShapePaddingZ
INTEGER                          :: NbrOfBGMCells(0:PartMPI%nProcs-1)
INTEGER                          :: Displacement(1:PartMPI%nProcs)
INTEGER, ALLOCATABLE             :: BGMCellsArray(:),CellProcNum(:,:,:)
INTEGER, ALLOCATABLE             :: GlobalBGMCellsArray(:), ReducedBGMArray(:)
INTEGER                          :: ReducedNbrOfBGMCells(0:PartMPI%nProcs-1)
INTEGER, ALLOCATABLE             :: CellProcList(:,:,:,:)
INTEGER                          :: tempproclist(0:PartMPI%nProcs-1)
INTEGER                          :: Vec1(1:3), Vec2(1:3), Vec3(1:3)
INTEGER                          :: ind, Shift(1:3), iCase
INTEGER                          :: j_offset
#endif /*MPI*/
!===================================================================================================================================

! zeros
#ifdef MPI
ii=0
jj=0
kk=0
#endif /*MPI*/


#ifdef MPI
  ! allocate and initialize MPINeighbor
  ALLOCATE(PartMPI%isMPINeighbor(0:PartMPI%nProcs-1))
  PartMPI%isMPINeighbor(:) = .FALSE.
  PartMPI%nMPINeighbors=0
#endif   


  CALL InitPeriodicBC()
  ! reduce beziercontrolpoints to boundary sides
  !IF(DoRefMapping) CALL ReshapeBezierSides()
  !CALL InitializeInterpolation() ! not any more required ! has to be called earliear
  CALL InitializeDeposition()     ! has to remain here, because domain can have changed
  !CALL InitPIC()                 ! does not depend on domain

! deallocate stuff // required for dynamic load balance
#ifdef MPI
IF (ALLOCATED(GEO%FIBGM)) THEN
  DO iBGM=GEO%FIBGMimin,GEO%FIBGMimax
    DO jBGM=GEO%FIBGMjmin,GEO%FIBGMjmax
      DO kBGM=GEO%FIBGMkmin,GEO%FIBGMkmax
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element)
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%ShapeProcs)
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%PaddingProcs)
!           SDEALLOCATE(GEO%FIBGM(i,k,l)%SharedProcs)
      END DO
    END DO
  END DO
  DEALLOCATE(GEO%FIBGM)
END IF
#endif /*MPI*/

!--- compute number of background cells in each direction
BGMimax = INT((GEO%xmax-GEO%xminglob)/GEO%FIBGMdeltas(1)+1.00001)
BGMimin = INT((GEO%xmin-GEO%xminglob)/GEO%FIBGMdeltas(1)+0.99999)
BGMjmax = INT((GEO%ymax-GEO%yminglob)/GEO%FIBGMdeltas(2)+1.00001)
BGMjmin = INT((GEO%ymin-GEO%yminglob)/GEO%FIBGMdeltas(2)+0.99999)
BGMkmax = INT((GEO%zmax-GEO%zminglob)/GEO%FIBGMdeltas(3)+1.00001)
BGMkmin = INT((GEO%zmin-GEO%zminglob)/GEO%FIBGMdeltas(3)+0.99999)

!--- JN: For MPI communication, information also about the neighboring FIBGM cells is needed
!--- AS: shouldn't we add up here the nPaddingCells? 
!--- TS: What we need to do is increase the BGM area for shape_function ONLY
!        Reason: if a particle moves outside the domain, there still needs to be a
!                BGM with an associated ShapeProc at the particle position
!        Particle may only move c*dt*Safetyfactor.
!--- PO: modified for curved and shape-function influence
!        c*dt*SafetyFactor+r_cutoff
IF (ManualTimeStep.EQ.0.0) THEN
#ifndef PP_HDG
  deltaT=CALCTIMESTEP()
#else
   CALL abort(&
__STAMP__&
, 'ManualTimeStep is not defined correctly!')
#endif /*PP_HDG*/
ELSE
  deltaT=ManualTimeStep
END IF
IF (halo_eps_velo.EQ.0) halo_eps_velo = c
#if (PP_TimeDiscMethod==4 || PP_TimeDiscMethod==200 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==1000)
IF (halo_eps_velo.EQ.c) THEN
   CALL abort(&
__STAMP__&
, 'Halo Eps Velocity for MPI not defined')
END IF
#endif
#if (PP_TimeDiscMethod==201)
deltaT=CALCTIMESTEP()
halo_eps = c*deltaT*SafetyFactor*max(dt_part_ratio,1.0)
#else
halo_eps = halo_eps_velo*deltaT*SafetyFactor ! for RK too large
#endif
halo_eps2=halo_eps*halo_eps
SWRITE(UNIT_stdOut,'(A38,E24.12)') ' |                 halo distance  |    ',halo_eps 

#ifdef MPI
IF ((DepositionType.EQ.'shape_function')             &
.OR.(DepositionType.EQ.'shape_function_cylindrical') &
.OR.(DepositionType.EQ.'shape_function_spherical')   &
.OR.(DepositionType.EQ.'shape_function_1d')          )THEN
  BGMimax = INT((MIN(GEO%xmax+halo_eps,GEO%xmaxglob)-GEO%xminglob)/GEO%FIBGMdeltas(1)+1.00001)
  BGMimin = INT((MAX(GEO%xmin-halo_eps,GEO%xminglob)-GEO%xminglob)/GEO%FIBGMdeltas(1)+0.99999)
  BGMjmax = INT((MIN(GEO%ymax+halo_eps,GEO%ymaxglob)-GEO%yminglob)/GEO%FIBGMdeltas(2)+1.00001)
  BGMjmin = INT((MAX(GEO%ymin-halo_eps,GEO%yminglob)-GEO%yminglob)/GEO%FIBGMdeltas(2)+0.99999)
  BGMkmax = INT((MIN(GEO%zmax+halo_eps,GEO%zmaxglob)-GEO%zminglob)/GEO%FIBGMdeltas(3)+1.00001)
  BGMkmin = INT((MAX(GEO%zmin-halo_eps,GEO%zminglob)-GEO%zminglob)/GEO%FIBGMdeltas(3)+0.99999)
END IF
#endif

GEO%FIBGMimax=BGMimax
GEO%FIBGMimin=BGMimin
GEO%FIBGMjmax=BGMjmax
GEO%FIBGMjmin=BGMjmin
GEO%FIBGMkmax=BGMkmax
GEO%FIBGMkmin=BGMkmin

! allocate space for BGM
ALLOCATE(GEO%FIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  WRITE(*,'(A,6(I0,A))')'Problem allocating GEO%FIBGM(',BGMimin,':',BGMimax,',', &
                                                        BGMjmin,':',BGMjmax,',', &
                                                        BGMkmin,':',BGMkmax,')'
#ifdef MPI
  iProc=PartMPI%MyRank
#else
  iProc=0
#endif /*MPI*/
  CALL abort(&
__STAMP__&
, 'Problem allocating GEO%FIBGM!' )
END IF

! null number of element per BGM cell
DO kBGM = BGMkmin,BGMkmax
   DO jBGM = BGMjmin,BGMjmax
     DO iBGM = BGMimin,BGMimax
         GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
      END DO
   END DO
END DO

!--- compute number of elements in each background cell
DO iElem=1,PP_nElems
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(ElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(ElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(ElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(ElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(ElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(ElemToBGM(6,iElem),BGMkmax),BGMkmin)
  ! add ecurrent element to number of BGM-elems
  DO iBGM = BGMCellXmin,BGMCellXmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO kBGM = BGMCellZmin,BGMCellZmax
         GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

!--- allocate mapping variable and clean number for mapping (below)
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      IF(GEO%FIBGM(iBGM,jBGM,kBGM)%nElem.EQ.0) CYCLE
      ALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element(1:GEO%FIBGM(iBGM,jBGM,kBGM)%nElem))
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- map elements to background cells
DO iElem=1,PP_nElems
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(ElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(ElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(ElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(ElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(ElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(ElemToBGM(6,iElem),BGMkmax),BGMkmin)
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1    
        GEO%FIBGM(iBGM,jBGM,kBGM)%Element(GEO%FIBGM(iBGM,jBGM,kBGM)%nElem) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem


!IF(mode.EQ.2) RETURN
#ifdef MPI
!--- MPI stuff for background mesh (FastinitBGM)
BGMCells=0 
ALLOCATE(BGMCellsArray(1:(BGMimax-BGMimin+1)*(BGMjmax-BGMjmin+1)*(BGMkmax-BGMkmin+1)*3))
DO iBGM=BGMimin, BGMimax  !Count BGMCells with Elements inside and save their indices in BGMCellsArray
  DO jBGM=BGMjmin, BGMjmax
    DO kBGM=BGMkmin, BGMkmax
      IF (GEO%FIBGM(iBGM,jBGM,kBGM)%nElem .GT. 0) THEN
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!Communicate number of BGMCells
CALL MPI_ALLGATHER(BGMCells, 1, MPI_INTEGER, NbrOfBGMCells(0:PartMPI%nProcs-1), 1, MPI_INTEGER, PartMPI%COMM, IERROR) 
ALLOCATE(GlobalBGMCellsArray(1:SUM(NbrOfBGMCells)*3))
Displacement(1)=0
DO i=2, PartMPI%nProcs
  Displacement(i) = SUM(NbrOfBGMCells(0:i-2))*3
END DO
!Gather indices of every Procs' Cells
CALL MPI_ALLGATHERV(BGMCellsArray(1:BGMCells*3), BGMCells*3, MPI_INTEGER, GlobalBGMCellsArray, &    
                   & NbrOfBGMCells(0:PartMPI%nProcs-1)*3, Displacement, MPI_INTEGER, PartMPI%COMM, IERROR)

!--- JN: first: count required array size for ReducedBGMArray
!--- TS: Define padding stencil (max of halo and shape padding)
!        Reason: This padding is used to build the ReducedBGM, so any information 
!                outside this region is lost 
FIBGMCellPadding(1:3) = INT(halo_eps/GEO%FIBGMdeltas(1:3))+1
! halo region already included in BGM
!FIBGMCellPadding(1:3) = 0
nShapePaddingX = 0
nShapePaddingY = 0
nShapePaddingZ = 0
IF ((DepositionType.EQ.'shape_function')             &
.OR.(DepositionType.EQ.'shape_function_cylindrical') &
.OR.(DepositionType.EQ.'shape_function_spherical')   &
.OR.(DepositionType.EQ.'shape_function_1d')          )THEN
  nShapePaddingX = INT(r_sf/GEO%FIBGMdeltas(1)+0.9999999)
  nShapePaddingY = INT(r_sf/GEO%FIBGMdeltas(2)+0.9999999)
  nShapePaddingZ = INT(r_sf/GEO%FIBGMdeltas(3)+0.9999999)
  !IPWRITE(*,*) 'nShapePaddingX',nShapePaddingX
  !IPWRITE(*,*) 'nShapePaddingY',nShapePaddingY
  !IPWRITE(*,*) 'nShapePaddingZ',nShapePaddingZ
 ! IF(mode.EQ.2) THEN
 !   IF((nShapePaddingX.EQ.0)    &
 !     .OR.(nShapePaddingY.EQ.0) &
 !     .OR.(nShapePaddingZ.EQ.0))THEN 
 !       CALL abort(__STAMP__&
 !         'Error in stencil calculation for FIBGM and shape function')
 !   END IF
 ! END IF
! 0.999999 in order to prevent stencil to get too big in case of r_sf==c_int*deltas
!  -> worst case: last 0.000001 gets cut off -> insignificant
END IF
nPaddingCellsX = MAX(nShapePaddingX,FIBGMCellPadding(1))
nPaddingCellsY = MAX(nShapePaddingY,FIBGMCellPadding(2))
nPaddingCellsZ = MAX(nShapePaddingZ,FIBGMCellPadding(3))

j=0
CurrentProc=0
DO i=1, SUM(NbrOfBGMCells)*3, 3
  IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
    CurrentProc=CurrentProc+1
  END IF
  IF  (.NOT.(GlobalBGMCellsArray(i) .LT. BGMimin-nPaddingCellsX .OR. GlobalBGMCellsArray(i).GT. BGMimax+nPaddingCellsX &
      & .OR. GlobalBGMCellsArray(i+1) .LT. BGMjmin-nPaddingCellsY .OR. GlobalBGMCellsArray(i+1) .GT. BGMjmax+nPaddingCellsY &
      & .OR. GlobalBGMCellsArray(i+2) .LT. BGMkmin-nPaddingCellsZ .OR. GlobalBGMCellsArray(i+2) .GT. BGMkmax+nPaddingCellsZ &
      & .OR. CurrentProc .EQ. PartMPI%Myrank)) THEN
    j=j+3
  END IF
END DO !i

! Periodic: ReducedBGMArray needs to include cells on the other side of periodic vectors
! --- PO: CAUTION: changes throuogh curved
Vec1(1:3) = 0
Vec2(1:3) = 0
Vec3(1:3) = 0
IF (GEO%nPeriodicVectors.GT.0) THEN
  ! build case matrix
  IF (GEO%nPeriodicVectors.EQ.1) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  IF (GEO%nPeriodicVectors.EQ.2) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
      Vec2(ind) = INT(GEO%PeriodicVectors(ind,2)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  IF (GEO%nPeriodicVectors.EQ.3) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
      Vec2(ind) = INT(GEO%PeriodicVectors(ind,2)/GEO%FIBGMdeltas(ind)+0.1)
      Vec3(ind) = INT(GEO%PeriodicVectors(ind,3)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  CurrentProc=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    DO iCase = 1, NbrOfCases
      IF ((casematrix(iCase,1).EQ.0) .AND. &  ! DON'T DO THE UNMOVED PART, HAS BEEN DONE ABOVE
          (casematrix(iCase,2).EQ.0) .AND. &
          (casematrix(iCase,3).EQ.0)) CYCLE
      Shift(1:3) = casematrix(iCase,1)*Vec1(1:3) + &
                   casematrix(iCase,2)*Vec2(1:3) + &
                   casematrix(iCase,3)*Vec3(1:3)
      IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
        CurrentProc=CurrentProc+1
      END IF
      IF  (.NOT.(GlobalBGMCellsArray(i)  +Shift(1) .LT. BGMimin-nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i)  +Shift(1) .GT. BGMimax+nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i+1)+Shift(2) .LT. BGMjmin-nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+1)+Shift(2) .GT. BGMjmax+nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+2)+Shift(3) .LT. BGMkmin-nPaddingCellsZ &
           .OR.  GlobalBGMCellsArray(i+2)+Shift(3) .GT. BGMkmax+nPaddingCellsZ &
           .OR. CurrentProc .EQ. PartMPI%MyRank)) THEN
        j=j+3
      END IF
    END DO !iCase
  END DO !i
END IF !nPeriodic>0

ALLOCATE(ReducedBGMArray(1:j))
!Reduce GlobalBGMCellsArray: erase cells far away from iprocs domain
!--- JN: ReducedBGMArray contains data only from other MPI procs!

IF (GEO%nPeriodicVectors.GT.0) THEN  !Periodic (can't be done below because ReducedBGMArray is sorted by proc)
  j=1
  CurrentProc=0
  ReducedBGMArray=0
  ReducedNbrOfBGMCells=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    DO iCase = 1, NbrOfCases         ! This time INCLUDING non-moved
      Shift(1:3) = casematrix(iCase,1)*Vec1(1:3) + &
                   casematrix(iCase,2)*Vec2(1:3) + &
                   casematrix(iCase,3)*Vec3(1:3)
      IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
        CurrentProc=CurrentProc+1
      END IF
      IF  (.NOT.(GlobalBGMCellsArray(i)   +Shift(1) .LT. BGMimin-nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i)   +Shift(1) .GT. BGMimax+nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i+1) +Shift(2) .LT. BGMjmin-nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+1) +Shift(2) .GT. BGMjmax+nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+2) +Shift(3) .LT. BGMkmin-nPaddingCellsZ &
           .OR.  GlobalBGMCellsArray(i+2) +Shift(3) .GT. BGMkmax+nPaddingCellsZ &
           .OR.  CurrentProc .EQ. PartMPI%MyRank)) THEN
        ReducedBGMArray(j)=GlobalBGMCellsArray(i)     +Shift(1)
        ReducedBGMArray(j+1)=GlobalBGMCellsArray(i+1) +Shift(2)
        ReducedBGMArray(j+2)=GlobalBGMCellsArray(i+2) +Shift(3)
        j=j+3
        ReducedNbrOfBGMCells(CurrentProc)=ReducedNbrOfBGMCells(CurrentProc)+1
      END IF
    END DO ! iCase
  END DO !i
ELSE ! non periodic case
  j=1
  CurrentProc=0
  ReducedBGMArray=0
  ReducedNbrOfBGMCells=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
      CurrentProc=CurrentProc+1
    END IF
    IF  (.NOT.(GlobalBGMCellsArray(i)   .LT. BGMimin-nPaddingCellsX .OR. GlobalBGMCellsArray(i).GT.    BGMimax+nPaddingCellsX &
        & .OR. GlobalBGMCellsArray(i+1) .LT. BGMjmin-nPaddingCellsY .OR. GlobalBGMCellsArray(i+1) .GT. BGMjmax+nPaddingCellsY &
        & .OR. GlobalBGMCellsArray(i+2) .LT. BGMkmin-nPaddingCellsZ .OR. GlobalBGMCellsArray(i+2) .GT. BGMkmax+nPaddingCellsZ &
         & .OR. CurrentProc .EQ. PartMPI%MyRank)) THEN
      ReducedBGMArray(j  )=GlobalBGMCellsArray(i  )
      ReducedBGMArray(j+1)=GlobalBGMCellsArray(i+1)
      ReducedBGMArray(j+2)=GlobalBGMCellsArray(i+2)
      j=j+3
      ReducedNbrOfBGMCells(CurrentProc)=ReducedNbrOfBGMCells(CurrentProc)+1
    END IF
  END DO !i
END IF !periodic


!--- JN: Determine required size of CellProcList array (hope this works, everytime I try to again understand this
!        shape function parallelization stuff, I get confused...)
!--- JN: But therefore we first have to refill BGMCellsArray to not only contain
!        cells with PIC%FastInitBGM%nElem.GT.0 but also those adjacent to them!
!--- TS: Actually, not the adjacent cell needs to be considered but a shape_proc stencil
!        Usually, the shape function radius is chosen to be the size of one BGM, but this 
!        is not necessarily always true. Hence new shape_proc padding:

BGMCells=0 
DO iBGM=BGMimin, BGMimax  !Count BGMCells with Elements inside or adjacent and save their indices in BGMCellsArray
  DO jBGM=BGMjmin, BGMjmax
    DO kBGM=BGMkmin, BGMkmax
      iMin=MAX(iBGM-nShapePaddingX,BGMimin); iMax=MIN(iBGM+nShapePaddingX,BGMimax)
      jMin=MAX(jBGM-nShapePaddingY,BGMjmin); jMax=MIN(jBGM+nShapePaddingY,BGMjmax)
      kMin=MAX(kBGM-nShapePaddingZ,BGMkmin); kMax=MIN(kBGM+nShapePaddingZ,BGMkmax)
      IF (SUM(GEO%FIBGM(iMin:iMax,jMin:jMax,kMin:kMax)%nElem) .GT. 0) THEN
        ! debug here changed i,j,k to ibgm,jbgm,kbgm
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO !iBGM
  END DO !jBGM
END DO !kBGM

! now create a temporary array in which for all BGM Cells + ShapePadding the processes are saved 
! reason: this way, the ReducedBGM List only needs to be searched once and not once for each BGM Cell+Stencil

! first count the maximum number of procs that exist within each BGM cell (inkl. Shape Padding region)
ALLOCATE(CellProcNum(BGMimin-nShapePaddingX:BGMimax+nShapePaddingX, &
                     BGMjmin-nShapePaddingY:BGMjmax+nShapePaddingY, &
                     BGMkmin-nShapePaddingZ:BGMkmax+nShapePaddingZ))
CellProcNum = 0
Procs = 0 ! = maximum number of procs in one BGM cell
DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
  IF((ReducedBGMArray(j).GE.BGMimin-nShapePaddingX).AND.(ReducedBGMArray(j).LE.BGMimax+nShapePaddingX))THEN
    IF((ReducedBGMArray(j+1).GE.BGMjmin-nShapePaddingY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nShapePaddingY))THEN
      IF((ReducedBGMArray(j+2).GE.BGMkmin-nShapePaddingZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nShapePaddingZ))THEN !inside
        CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
        Procs = MAX(Procs, CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)))
      END IF
    END IF
  END IF
END DO
! allocate the temporary array
ALLOCATE(CellProcList(BGMimin-nShapePaddingX:BGMimax+nShapePaddingX, &
                      BGMjmin-nShapePaddingY:BGMjmax+nShapePaddingY, &
                      BGMkmin-nShapePaddingZ:BGMkmax+nShapePaddingZ, &
                      1:Procs))
CellProcList = -1

! fill array with proc numbers

CellProcNum = 0
j_offset = 0
DO CurrentProc = 0,PartMPI%nProcs-1
  DO j = 1+j_offset, ReducedNbrOfBGMCells(CurrentProc)*3-2+j_offset,3
    IF((ReducedBGMArray(j).GE.BGMimin-nShapePaddingX).AND.(ReducedBGMArray(j).LE.BGMimax+nShapePaddingX))THEN
      IF((ReducedBGMArray(j+1).GE.BGMjmin-nShapePaddingY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nShapePaddingY))THEN
        IF((ReducedBGMArray(j+2).GE.BGMkmin-nShapePaddingZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nShapePaddingZ))THEN
          CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
          CellProcList(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2), &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2))) = CurrentProc
        END IF
      END IF
    END IF
  END DO
  j_offset = j_offset + ReducedNbrOfBGMCells(CurrentProc)*3
END DO
! fill real array
DO Cell=0, BGMCells-1
  TempProcList=0
  DO iBGM = BGMCellsArray(Cell*3+1)-nShapePaddingX, BGMCellsArray(Cell*3+1)+nShapePaddingX
    DO jBGM = BGMCellsArray(Cell*3+2)-nShapePaddingY, BGMCellsArray(Cell*3+2)+nShapePaddingY
      DO kBGM = BGMCellsArray(Cell*3+3)-nShapePaddingZ, BGMCellsArray(Cell*3+3)+nShapePaddingZ
        DO m = 1,CellProcNum(iBGM,jBGM,kBGM)
          TempProcList(CellProcList(iBGM,jBGM,kBGM,m))=1       ! every proc that is within the stencil gets a 1
        END DO ! m
        kk = kBGM
      END DO !kBGM
      jj = jBGM
    END DO !jBGM
    ii = iBGM
  END DO !iBGM
  Procs=SUM(TempProcList)
  IF (Procs.NE.0) THEN
    ALLOCATE(GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(1:Procs+1))
    GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(1) = Procs
    j=2
    DO m=0,PartMPI%nProcs-1
      IF (TempProcList(m) .EQ. 1) THEN
        IF(.NOT.PartMPI%isMPINeighbor(m))THEN
          !IF(mode.EQ.2)THEN
          !  IPWRITE(UNIT_stdOut,*) ' Warning, something wrong with halo region'
          !  CALL abort(__STAMP__&
          !      , ' Something wrong with Halo region' )
          !END IF
          PartMPI%isMPINeighbor(m) = .true.
          PartMPI%nMPINeighbors=PartMPI%nMPINeighbors+1
        END IF
        GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(j)=m
        j=j+1
      END IF
    END DO !m
  END IF
END DO !Cell

   !Compare own BGMCells and their Neighbors with ReducedBGMArray and save other Processes in BGM-Cells
   !--- JN: ReducedBGMArray contains data only from other MPI procs!
   !--- JN: BGMCellsArray contains in index triplets (i,k,l) all BGM cells containing elements from the local MPI proc
   !        plus the index triplets of BGM cells adjacent to cells containing elements from the local MPI proc

!   !--- JN: First identify only procs that share the exact same BGM cell as I (SharedProcs)
!   Procs = 0
!   CellProcList=-1
!   DO Cell=0, BGMCells-1
!     TempProcList=0
!     i = BGMCellsArray(Cell*3+1)
!     k = BGMCellsArray(Cell*3+2)
!     l = BGMCellsArray(Cell*3+3)
!     IF (GEO%FIBGM(i,k,l)%nElem.EQ.0) CYCLE
!     CurrentProc=0
!     m=2
!     DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
!       !--- JN: Slide CurrentProc to the MPI Proc that the currently checked BGMCell belongs to
!       DO WHILE (j .GT. SUM(ReducedNbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PMPIVAR%nProcs-1)
!         CurrentProc=CurrentProc+1
!       END DO
!       IF (i .EQ. ReducedBGMArray(j) .AND. k .EQ. ReducedBGMArray(j+1) .AND. l .EQ. ReducedBGMArray(j+2)) THEN
!         IF (m .GT. MaxShapeProcs) THEN
!           CALL abort(__STAMP__&
!                                'ERROR in Boundary_PIC.f90: Cellproclist can contain only MaxShapeProcs=',MaxShapeProcs,999.)
!         END IF
!         CellProcList(i,k,l,m)=CurrentProc
!         m=m+1
!         TempProcList(CurrentProc)=1
!       END IF
!     END DO !j
!     Procs=SUM(TempProcList)
!     ALLOCATE(GEO%FIBGM(i,k,l)%SharedProcs(1:Procs+1)) 
!     GEO%FIBGM(i,k,l)%SharedProcs(1) = Procs
!     j=2
!     DO m=0,PMPIVAR%nProcs-1
!       IF (TempProcList(m) .EQ. 1) THEN
!         GEO%FIBGM(i,k,l)%SharedProcs(j)=m
!         j=j+1
!       END IF
!     END DO !m
!   END DO !Cell


! ----------------------------------------------------------------!
!--- AS: Do it again for Paddingcells
DEALLOCATE(CellProcList)
DEALLOCATE(CellProcNum)
!--- JN: Determine required size of CellProcList array (hope this works, everytime I try to again understand this
!        shape function parallelization stuff, I get confused...)
!--- JN: But therefore we first have to refill BGMCellsArray to not only contain
!        cells with PIC%FastInitBGM%nElem.GT.0 but also those adjacent and the paddingcells to them!
BGMCells=0
DO iBGM=BGMimin, BGMimax  !Count BGMCells with Elements inside or adjacent and save their indices in BGMCellsArray
  DO jBGM=BGMjmin, BGMjmax
    DO kBGM=BGMkmin, BGMkmax
      iMin=MAX(iBGM-nPaddingCellsX,BGMimin); iMax=MIN(iBGM+nPaddingCellsX,BGMimax)
      jMin=MAX(jBGM-nPaddingCellsY,BGMjmin); jMax=MIN(jBGM+nPaddingCellsY,BGMjmax)
      kMin=MAX(kBGM-nPaddingCellsZ,BGMkmin); kMax=MIN(kBGM+nPaddingCellsZ,BGMkmax)
      IF (SUM(GEO%FIBGM(iMin:iMax,jMin:jMax,kMin:kMax)%nElem) .GT. 0) THEN
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO !iBGM
  END DO !jBGM
END DO !kBGM

! now create a temporary array in which for all BGM Cells + ShapePadding the processes are saved 
! reason: this way, the ReducedBGM List only needs to be searched once and not once for each BGM Cell+Stencil

! first count the maximum number of procs that exist within each BGM cell (inkl. Shape Padding region)
ALLOCATE(CellProcNum(BGMimin-nPaddingCellsX:BGMimax+nPaddingCellsX, &
                     BGMjmin-nPaddingCellsY:BGMjmax+nPaddingCellsY, &
                     BGMkmin-nPaddingCellsZ:BGMkmax+nPaddingCellsZ))
CellProcNum = 0
Procs = 0
DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
   IF((ReducedBGMArray(j).GE.BGMimin-nPaddingCellsX).AND.(ReducedBGMArray(j).LE.BGMimax+nPaddingCellsX))THEN
     IF((ReducedBGMArray(j+1).GE.BGMjmin-nPaddingCellsY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nPaddingCellsY))THEN
       IF((ReducedBGMArray(j+2).GE.BGMkmin-nPaddingCellsZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nPaddingCellsZ))THEN
        CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
        Procs = MAX(Procs, CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)))
       END IF
     END IF
   END IF
END DO
! allocate the temporary array
ALLOCATE(CellProcList(BGMimin-nPaddingCellsX:BGMimax+nPaddingCellsX, &
                      BGMjmin-nPaddingCellsY:BGMjmax+nPaddingCellsY, &
                      BGMkmin-nPaddingCellsZ:BGMkmax+nPaddingCellsZ, &
                      1:Procs))
CellProcList = -1

! fill array with proc numbers

CellProcNum = 0
j_offset = 0
DO CurrentProc = 0,PartMPI%nProcs-1
  DO j = 1+j_offset, j_offset+ReducedNbrOfBGMCells(CurrentProc)*3-2,3
    CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
    CellProcList(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2), &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2))) = CurrentProc
  END DO
  j_offset = j_offset + ReducedNbrOfBGMCells(CurrentProc)*3
END DO

! fill real array
DO Cell=0, BGMCells-1
  TempProcList=0
  DO iBGM = BGMCellsArray(Cell*3+1)-nPaddingCellsX, BGMCellsArray(Cell*3+1)+nPaddingCellsX
    DO jBGM = BGMCellsArray(Cell*3+2)-nPaddingCellsY, BGMCellsArray(Cell*3+2)+nPaddingCellsY
      DO kBGM = BGMCellsArray(Cell*3+3)-nPaddingCellsZ, BGMCellsArray(Cell*3+3)+nPaddingCellsZ
        DO m = 1,CellProcNum(iBGM,jBGM,kBGM)
          TempProcList(CellProcList(iBGM,jBGM,kBGM,m))=1       ! every proc that is within the stencil gets a 1
        END DO ! m
        kk = kBGM
      END DO !l
      jj = jBGM
    END DO !k
    ii = iBGM
  END DO !i
  Procs=SUM(TempProcList)
  IF (Procs.NE.0) THEN
    ALLOCATE(GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(1:Procs+1))
    GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(1) = Procs
    j=2
    DO m=0,PartMPI%nProcs-1
      IF (TempProcList(m) .EQ. 1) THEN
        GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(j)=m
        j=j+1
      END IF
    END DO !m
  END IF
END DO !Cell
DEALLOCATE(ReducedBGMArray, BGMCellsArray, CellProcList, GlobalBGMCellsArray, CellProcNum)
#endif /*MPI*/

END SUBROUTINE GetFIBGM


SUBROUTINE GetSFIBGM()
!===================================================================================================================================
! build local FIBGM mesh for process local FIBGM mesh including HALO region
! mode 1: build local BGM and interconnections with other processes
! mode 2: rebuild BGM including HALO region
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals!,            ONLY : UNIT_StdOut
USE MOD_Particle_Mesh_Vars,                 ONLY:ElemBaryNGeo,ElemRadiusNGeo
!USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D
USE MOD_Partilce_Periodic_BC,               ONLY:InitPeriodicBC
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems,nTotalSides
USE MOD_PICDepo,                            ONLY:InitializeDeposition
USE MOD_Particle_MPI_Vars,                  ONLY:SafetyFactor,halo_eps_velo,halo_eps,halo_eps2
#ifndef PP_HDG
USE MOD_CalcTimeStep,                       ONLY:CalcTimeStep
#endif /*PP_HDG*/
USE MOD_Equation_Vars,                      ONLY:c
USE MOD_Particle_Vars,                      ONLY:manualtimestep
#if (PP_TimeDiscMethod==201)
USE MOD_Particle_Vars,                      ONLY:dt_part_ratio
#endif
USE MOD_ChangeBasis,                        ONLY:ChangeBasis2D
#ifdef MPI
USE MOD_Particle_Mesh_Vars,                 ONLY:FIBGMCellPadding
USE MOD_PICDepo_Vars,                       ONLY:DepositionType, r_sf
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
USE MOD_Particle_Mesh_Vars,                 ONLY:NbrOfCases,casematrix
#endif /*MPI*/

! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!INTEGER,INTENT(IN)    :: mode
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!REAL                  :: localXmin,localXmax,localymin,localymax,localzmin,localzmax
INTEGER                          :: BGMimin,BGMimax,BGMjmin,BGMjmax,BGMkmin,BGMkmax
REAL                             :: xmin, xmax, ymin, ymax, zmin, zmax
INTEGER                          :: iBGM,jBGM,kBGM,iElem,iSide
INTEGER                          :: BGMCellXmax,BGMCellXmin
INTEGER                          :: BGMCellYmax,BGMCellYmin
INTEGER                          :: BGMCellZmax,BGMCellZmin
INTEGER                          :: ALLOCSTAT
INTEGER                          :: iProc
INTEGER                          :: nEntry
REAL                             :: deltaT
#ifdef MPI
INTEGER                          :: ii,jj,kk,i,j
INTEGER                          :: BGMCells,  m, CurrentProc, Cell, Procs,Cell3
INTEGER                          :: imin, imax, kmin, kmax, jmin, jmax
INTEGER                          :: nPaddingCellsX, nPaddingCellsY, nPaddingCellsZ
INTEGER                          :: nShapePaddingX, nShapePaddingY, nShapePaddingZ
INTEGER                          :: NbrOfBGMCells(0:PartMPI%nProcs-1)
INTEGER                          :: Displacement(1:PartMPI%nProcs)
INTEGER, ALLOCATABLE             :: BGMCellsArray(:),CellProcNum(:,:,:)
INTEGER, ALLOCATABLE             :: GlobalBGMCellsArray(:), ReducedBGMArray(:)
INTEGER                          :: ReducedNbrOfBGMCells(0:PartMPI%nProcs-1)
INTEGER, ALLOCATABLE             :: CellProcList(:,:,:,:)
INTEGER                          :: tempproclist(0:PartMPI%nProcs-1)
INTEGER                          :: Vec1(1:3), Vec2(1:3), Vec3(1:3)
INTEGER                          :: ind, Shift(1:3), iCase
INTEGER                          :: j_offset
#endif /*MPI*/
!===================================================================================================================================

! zeros
#ifdef MPI
ii=0
jj=0
kk=0
#endif /*MPI*/

!#ifdef MPI
!   !--- If this MPI process does not contain particles, step out
!   IF (PMPIVAR%GROUP.EQ.MPI_GROUP_EMPTY) RETURN
!#endif
!--- calc min and max coordinates for mesh
xmin = HUGE(1.0)
xmax =-HUGE(1.0)
ymin = HUGE(1.0)
ymax =-HUGE(1.0)
zmin = HUGE(1.0)
zmax =-HUGE(1.0)

! serch for min,max of BezierControlPoints, e.g. the convec hull of the domain
! bounding box!!
!DO iSide=1,nTotalSides
!  xmin=MIN(xmin,MINVAL(BezierControlPoints3D(1,:,:,iSide)))
!  xmax=MAX(xmax,MAXVAL(BezierControlPoints3D(1,:,:,iSide)))
!  ymin=MIN(ymin,MINVAL(BezierControlPoints3D(2,:,:,iSide)))
!  ymax=MAX(ymax,MAXVAL(BezierControlPoints3D(2,:,:,iSide)))
!  zmin=MIN(zmin,MINVAL(BezierControlPoints3D(3,:,:,iSide)))
!  zmax=MAX(zmax,MAXVAL(BezierControlPoints3D(3,:,:,iSide)))
!END DO ! iSide

DO iElem=1,nTotalElems
  xmin=MIN(xmin,ElemBaryNGeo(1,iElem)-ElemRadiusNGeo(iElem))
  xmax=MAX(xmax,ElemBaryNGeo(1,iElem)+ElemRadiusNGeo(iElem))
  ymin=MIN(ymin,ElemBaryNGeo(2,iElem)-ElemRadiusNGeo(iElem))
  ymax=MAX(ymax,ElemBaryNGeo(2,iElem)+ElemRadiusNGeo(iElem))
  zmin=MIN(zmin,ElemBaryNGeo(3,iElem)-ElemRadiusNGeo(iElem))
  zmax=MAX(zmax,ElemBaryNGeo(3,iElem)+ElemRadiusNGeo(iElem))
END DO 


GEO%xmin=xmin
GEO%xmax=xmax
GEO%ymin=ymin
GEO%ymax=ymax
GEO%zmin=zmin
GEO%zmax=zmax

#ifdef MPI
  ! allocate and initialize MPINeighbor
  ALLOCATE(PartMPI%isMPINeighbor(0:PartMPI%nProcs-1))
  PartMPI%isMPINeighbor(:) = .FALSE.
  PartMPI%nMPINeighbors=0

! get global min, max
  CALL MPI_ALLREDUCE(GEO%xmin, GEO%xminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%ymin, GEO%yminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%zmin, GEO%zminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%xmax, GEO%xmaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%ymax, GEO%ymaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%zmax, GEO%zmaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
#else
  GEO%xminglob=GEO%xmin
  GEO%yminglob=GEO%ymin
  GEO%zminglob=GEO%zmin
  GEO%xmaxglob=GEO%xmax
  GEO%ymaxglob=GEO%ymax
  GEO%zmaxglob=GEO%zmax
#endif   

  CALL InitPeriodicBC()
  ! reduce beziercontrolpoints to boundary sides
  !IF(DoRefMapping) CALL ReshapeBezierSides()
  !CALL InitializeInterpolation() ! not any more required ! has to be called earliear
  CALL InitializeDeposition()     ! has to remain here, because domain can have changed
  !CALL InitPIC()                 ! does not depend on domain

! deallocate stuff // required for dynamic load balance
#ifdef MPI
IF (ALLOCATED(GEO%FIBGM)) THEN
  DO kBGM=GEO%FIBGMkmin,GEO%FIBGMkmax
    DO jBGM=GEO%FIBGMjmin,GEO%FIBGMjmax
      DO iBGM=GEO%FIBGMimin,GEO%FIBGMimax
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element)
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%ShapeProcs)
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%PaddingProcs)
!           SDEALLOCATE(GEO%FIBGM(i,k,l)%SharedProcs)
      END DO
    END DO
  END DO
  DEALLOCATE(GEO%FIBGM)
END IF
#endif /*MPI*/

!--- compute number of background cells in each direction
BGMimax = INT((GEO%xmax-GEO%xminglob)/GEO%FIBGMdeltas(1)+1.00001)
BGMimin = INT((GEO%xmin-GEO%xminglob)/GEO%FIBGMdeltas(1)+0.99999)
BGMjmax = INT((GEO%ymax-GEO%yminglob)/GEO%FIBGMdeltas(2)+1.00001)
BGMjmin = INT((GEO%ymin-GEO%yminglob)/GEO%FIBGMdeltas(2)+0.99999)
BGMkmax = INT((GEO%zmax-GEO%zminglob)/GEO%FIBGMdeltas(3)+1.00001)
BGMkmin = INT((GEO%zmin-GEO%zminglob)/GEO%FIBGMdeltas(3)+0.99999)

!--- JN: For MPI communication, information also about the neighboring FIBGM cells is needed
!--- AS: shouldn't we add up here the nPaddingCells? 
!--- TS: What we need to do is increase the BGM area for shape_function ONLY
!        Reason: if a particle moves outside the domain, there still needs to be a
!                BGM with an associated ShapeProc at the particle position
!        Particle may only move c*dt*Safetyfactor.
!--- PO: modified for curved and shape-function influence
!        c*dt*SafetyFactor+r_cutoff
IF (ManualTimeStep.EQ.0.0) THEN
#ifndef PP_HDG
  deltaT=CALCTIMESTEP()
#else
   CALL abort(&
__STAMP__&
, 'ManualTimeStep is not defined correctly!')
#endif /*PP_HDG*/
ELSE
  deltaT=ManualTimeStep
END IF
IF (halo_eps_velo.EQ.0) halo_eps_velo = c
#if (PP_TimeDiscMethod==4 || PP_TimeDiscMethod==200 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==1000)
IF (halo_eps_velo.EQ.c) THEN
   CALL abort(&
__STAMP__&
, 'Halo Eps Velocity for MPI not defined')
END IF
#endif
#if (PP_TimeDiscMethod==201)
deltaT=CALCTIMESTEP()
halo_eps = c*deltaT*SafetyFactor*max(dt_part_ratio,1.0)
#else
halo_eps = halo_eps_velo*deltaT*SafetyFactor ! for RK too large
#endif
halo_eps2=halo_eps*halo_eps
SWRITE(UNIT_stdOut,'(A38,E24.12)') ' |                 halo distance  |    ',halo_eps 

#ifdef MPI
IF ((DepositionType.EQ.'shape_function') &
.OR.(DepositionType.EQ.'cylindrical_shape_function') &
.OR.(DepositionType.EQ.'shape_function_1d'))THEN
  BGMimax = INT((MIN(GEO%xmax+halo_eps,GEO%xmaxglob)-GEO%xminglob)/GEO%FIBGMdeltas(1)+1.00001)
  BGMimin = INT((MAX(GEO%xmin-halo_eps,GEO%xminglob)-GEO%xminglob)/GEO%FIBGMdeltas(1)+0.99999)
  BGMjmax = INT((MIN(GEO%ymax+halo_eps,GEO%ymaxglob)-GEO%yminglob)/GEO%FIBGMdeltas(2)+1.00001)
  BGMjmin = INT((MAX(GEO%ymin-halo_eps,GEO%yminglob)-GEO%yminglob)/GEO%FIBGMdeltas(2)+0.99999)
  BGMkmax = INT((MIN(GEO%zmax+halo_eps,GEO%zmaxglob)-GEO%zminglob)/GEO%FIBGMdeltas(3)+1.00001)
  BGMkmin = INT((MAX(GEO%zmin-halo_eps,GEO%zminglob)-GEO%zminglob)/GEO%FIBGMdeltas(3)+0.99999)
END IF
#endif

GEO%FIBGMimax=BGMimax
GEO%FIBGMimin=BGMimin
GEO%FIBGMjmax=BGMjmax
GEO%FIBGMjmin=BGMjmin
GEO%FIBGMkmax=BGMkmax
GEO%FIBGMkmin=BGMkmin

! allocate space for BGM
ALLOCATE(GEO%FIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  WRITE(*,'(A,6(I0,A))')'Problem allocating GEO%FIBGM(',BGMimin,':',BGMimax,',', &
                                                        BGMjmin,':',BGMjmax,',', &
                                                        BGMkmin,':',BGMkmax,')'
#ifdef MPI
  iProc=PartMPI%MyRank
#else
  iProc=0
#endif /*MPI*/
  CALL abort(&
__STAMP__&
, 'Problem allocating GEO%FIBGM!' )
END IF

! null number of element per BGM cell
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
         GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
      END DO
   END DO
END DO

!--- compute number of elements in each background cell
DO iElem=1,nTotalElems

  ! get elem extension based on barycenter and radius
  xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
  ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
  zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
  xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
  ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
  zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)


    !--- find minimum and maximum BGM cell for current element
  BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
  BGMCellXmax = MIN(BGMCellXmax,BGMimax)
  BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
  BGMCellXmin = MAX(BGMCellXmin,BGMimin)
  BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
  BGMCellYmax = MIN(BGMCellYmax,BGMjmax)
  BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
  BGMCellYmin = MAX(BGMCellYmin,BGMjmin)
  BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
  BGMCellZmax = MIN(BGMCellZmax,BGMkmax)
  BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
  BGMCellZmin = MAX(BGMCellZmin,BGMkmin)      
  ! add ecurrent element to number of BGM-elems
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
         GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

!--- allocate mapping variable and clean number for mapping (below)
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      ALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element(1:GEO%FIBGM(iBGM,jBGM,kBGM)%nElem))
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- map elements to background cells
DO iElem=1,nTotalElems
  ! get elem extension based on barycenter and radius
  xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
  ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
  zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
  xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
  ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
  zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)

  ! same as above
  BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
  BGMCellXmax = MIN(BGMCellXmax,BGMimax)
  BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
  BGMCellXmin = MAX(BGMCellXmin,BGMimin)
  BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
  BGMCellYmax = MIN(BGMCellYmax,BGMjmax)
  BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
  BGMCellYmin = MAX(BGMCellYmin,BGMjmin)
  BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
  BGMCellZmax = MIN(BGMCellZmax,BGMkmax)
  BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
  BGMCellZmin = MAX(BGMCellZmin,BGMkmin)     
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        nEntry = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
        nEntry = nEntry+1
        !GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1    
        GEO%FIBGM(iBGM,jBGM,kBGM)%Element(nEntry) = iElem
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = nEntry
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem


!IF(mode.EQ.2) RETURN
#ifdef MPI
!--- MPI stuff for background mesh (FastinitBGM)
BGMCells=0 
ALLOCATE(BGMCellsArray(1:(BGMimax-BGMimin+1)*(BGMjmax-BGMjmin+1)*(BGMkmax-BGMkmin+1)*3))
DO kBGM=BGMkmin, BGMkmax
  DO jBGM=BGMjmin, BGMjmax
    DO iBGM=BGMimin, BGMimax  !Count BGMCells with Elements inside and save their indices in BGMCellsArray
      IF (GEO%FIBGM(iBGM,jBGM,kBGM)%nElem .GT. 0) THEN
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!Communicate number of BGMCells
CALL MPI_ALLGATHER(BGMCells, 1, MPI_INTEGER, NbrOfBGMCells(0:PartMPI%nProcs-1), 1, MPI_INTEGER, PartMPI%COMM, IERROR) 
ALLOCATE(GlobalBGMCellsArray(1:SUM(NbrOfBGMCells)*3))
Displacement(1)=0
DO i=2, PartMPI%nProcs
  Displacement(i) = SUM(NbrOfBGMCells(0:i-2))*3
END DO
!Gather indices of every Procs' Cells
CALL MPI_ALLGATHERV(BGMCellsArray(1:BGMCells*3), BGMCells*3, MPI_INTEGER, GlobalBGMCellsArray, &    
                   & NbrOfBGMCells(0:PartMPI%nProcs-1)*3, Displacement, MPI_INTEGER, PartMPI%COMM, IERROR)

!--- JN: first: count required array size for ReducedBGMArray
!--- TS: Define padding stencil (max of halo and shape padding)
!        Reason: This padding is used to build the ReducedBGM, so any information 
!                outside this region is lost 
FIBGMCellPadding(1:3) = INT(halo_eps/GEO%FIBGMdeltas(1:3))+1
! halo region already included in BGM
!FIBGMCellPadding(1:3) = 0
nShapePaddingX = 0
nShapePaddingY = 0
nShapePaddingZ = 0
IF ((DepositionType.EQ.'shape_function') &
.OR.(DepositionType.EQ.'cylindrical_shape_function') &
.OR.(DepositionType.EQ.'shape_function_1d'))THEN
  nShapePaddingX = INT(r_sf/GEO%FIBGMdeltas(1)+0.9999999)
  nShapePaddingY = INT(r_sf/GEO%FIBGMdeltas(2)+0.9999999)
  nShapePaddingZ = INT(r_sf/GEO%FIBGMdeltas(3)+0.9999999)
  !IPWRITE(*,*) 'nShapePaddingX',nShapePaddingX
  !IPWRITE(*,*) 'nShapePaddingY',nShapePaddingY
  !IPWRITE(*,*) 'nShapePaddingZ',nShapePaddingZ
 ! IF(mode.EQ.2) THEN
 !   IF((nShapePaddingX.EQ.0)    &
 !     .OR.(nShapePaddingY.EQ.0) &
 !     .OR.(nShapePaddingZ.EQ.0))THEN 
 !       CALL abort(__STAMP__&
 !         'Error in stencil calculation for FIBGM and shape function')
 !   END IF
 ! END IF
! 0.999999 in order to prevent stencil to get too big in case of r_sf==c_int*deltas
!  -> worst case: last 0.000001 gets cut off -> insignificant
END IF
nPaddingCellsX = MAX(nShapePaddingX,FIBGMCellPadding(1))
nPaddingCellsY = MAX(nShapePaddingY,FIBGMCellPadding(2))
nPaddingCellsZ = MAX(nShapePaddingZ,FIBGMCellPadding(3))

j=0
CurrentProc=0
DO i=1, SUM(NbrOfBGMCells)*3, 3
  IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
    CurrentProc=CurrentProc+1
  END IF
  IF  (.NOT.(GlobalBGMCellsArray(i) .LT. BGMimin-nPaddingCellsX .OR. GlobalBGMCellsArray(i).GT. BGMimax+nPaddingCellsX &
      & .OR. GlobalBGMCellsArray(i+1) .LT. BGMjmin-nPaddingCellsY .OR. GlobalBGMCellsArray(i+1) .GT. BGMjmax+nPaddingCellsY &
      & .OR. GlobalBGMCellsArray(i+2) .LT. BGMkmin-nPaddingCellsZ .OR. GlobalBGMCellsArray(i+2) .GT. BGMkmax+nPaddingCellsZ &
      & .OR. CurrentProc .EQ. PartMPI%Myrank)) THEN
    j=j+3
  END IF
END DO !i

! Periodic: ReducedBGMArray needs to include cells on the other side of periodic vectors
! --- PO: CAUTION: changes throuogh curved
Vec1(1:3) = 0
Vec2(1:3) = 0
Vec3(1:3) = 0
IF (GEO%nPeriodicVectors.GT.0) THEN
  ! build case matrix
  IF (GEO%nPeriodicVectors.EQ.1) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  IF (GEO%nPeriodicVectors.EQ.2) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
      Vec2(ind) = INT(GEO%PeriodicVectors(ind,2)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  IF (GEO%nPeriodicVectors.EQ.3) THEN
    DO ind = 1,3
      Vec1(ind) = INT(GEO%PeriodicVectors(ind,1)/GEO%FIBGMdeltas(ind)+0.1)
      Vec2(ind) = INT(GEO%PeriodicVectors(ind,2)/GEO%FIBGMdeltas(ind)+0.1)
      Vec3(ind) = INT(GEO%PeriodicVectors(ind,3)/GEO%FIBGMdeltas(ind)+0.1)
    END DO
  END IF
  CurrentProc=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    DO iCase = 1, NbrOfCases
      IF ((casematrix(iCase,1).EQ.0) .AND. &  ! DON'T DO THE UNMOVED PART, HAS BEEN DONE ABOVE
          (casematrix(iCase,2).EQ.0) .AND. &
          (casematrix(iCase,3).EQ.0)) CYCLE
      Shift(1:3) = casematrix(iCase,1)*Vec1(1:3) + &
                   casematrix(iCase,2)*Vec2(1:3) + &
                   casematrix(iCase,3)*Vec3(1:3)
      IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
        CurrentProc=CurrentProc+1
      END IF
      IF  (.NOT.(GlobalBGMCellsArray(i)  +Shift(1) .LT. BGMimin-nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i)  +Shift(1) .GT. BGMimax+nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i+1)+Shift(2) .LT. BGMjmin-nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+1)+Shift(2) .GT. BGMjmax+nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+2)+Shift(3) .LT. BGMkmin-nPaddingCellsZ &
           .OR.  GlobalBGMCellsArray(i+2)+Shift(3) .GT. BGMkmax+nPaddingCellsZ &
           .OR. CurrentProc .EQ. PartMPI%MyRank)) THEN
        j=j+3
      END IF
    END DO !iCase
  END DO !i
END IF !nPeriodic>0

ALLOCATE(ReducedBGMArray(1:j))
!Reduce GlobalBGMCellsArray: erase cells far away from iprocs domain
!--- JN: ReducedBGMArray contains data only from other MPI procs!

IF (GEO%nPeriodicVectors.GT.0) THEN  !Periodic (can't be done below because ReducedBGMArray is sorted by proc)
  j=1
  CurrentProc=0
  ReducedBGMArray=0
  ReducedNbrOfBGMCells=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    DO iCase = 1, NbrOfCases         ! This time INCLUDING non-moved
      Shift(1:3) = casematrix(iCase,1)*Vec1(1:3) + &
                   casematrix(iCase,2)*Vec2(1:3) + &
                   casematrix(iCase,3)*Vec3(1:3)
      IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
        CurrentProc=CurrentProc+1
      END IF
      IF  (.NOT.(GlobalBGMCellsArray(i)   +Shift(1) .LT. BGMimin-nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i)   +Shift(1) .GT. BGMimax+nPaddingCellsX &
           .OR.  GlobalBGMCellsArray(i+1) +Shift(2) .LT. BGMjmin-nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+1) +Shift(2) .GT. BGMjmax+nPaddingCellsY &
           .OR.  GlobalBGMCellsArray(i+2) +Shift(3) .LT. BGMkmin-nPaddingCellsZ &
           .OR.  GlobalBGMCellsArray(i+2) +Shift(3) .GT. BGMkmax+nPaddingCellsZ &
           .OR.  CurrentProc .EQ. PartMPI%MyRank)) THEN
        ReducedBGMArray(j)=GlobalBGMCellsArray(i)     +Shift(1)
        ReducedBGMArray(j+1)=GlobalBGMCellsArray(i+1) +Shift(2)
        ReducedBGMArray(j+2)=GlobalBGMCellsArray(i+2) +Shift(3)
        j=j+3
        ReducedNbrOfBGMCells(CurrentProc)=ReducedNbrOfBGMCells(CurrentProc)+1
      END IF
    END DO ! iCase
  END DO !i
ELSE ! non periodic case
  j=1
  CurrentProc=0
  ReducedBGMArray=0
  ReducedNbrOfBGMCells=0
  DO i=1, SUM(NbrOfBGMCells)*3, 3
    IF  (i .GT. SUM(NbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PartMPI%nProcs-1) THEN
      CurrentProc=CurrentProc+1
    END IF
    IF  (.NOT.(GlobalBGMCellsArray(i)   .LT. BGMimin-nPaddingCellsX .OR. GlobalBGMCellsArray(i).GT.    BGMimax+nPaddingCellsX &
        & .OR. GlobalBGMCellsArray(i+1) .LT. BGMjmin-nPaddingCellsY .OR. GlobalBGMCellsArray(i+1) .GT. BGMjmax+nPaddingCellsY &
        & .OR. GlobalBGMCellsArray(i+2) .LT. BGMkmin-nPaddingCellsZ .OR. GlobalBGMCellsArray(i+2) .GT. BGMkmax+nPaddingCellsZ &
         & .OR. CurrentProc .EQ. PartMPI%MyRank)) THEN
      ReducedBGMArray(j  )=GlobalBGMCellsArray(i  )
      ReducedBGMArray(j+1)=GlobalBGMCellsArray(i+1)
      ReducedBGMArray(j+2)=GlobalBGMCellsArray(i+2)
      j=j+3
      ReducedNbrOfBGMCells(CurrentProc)=ReducedNbrOfBGMCells(CurrentProc)+1
    END IF
  END DO !i
END IF !periodic


!--- JN: Determine required size of CellProcList array (hope this works, everytime I try to again understand this
!        shape function parallelization stuff, I get confused...)
!--- JN: But therefore we first have to refill BGMCellsArray to not only contain
!        cells with PIC%FastInitBGM%nElem.GT.0 but also those adjacent to them!
!--- TS: Actually, not the adjacent cell needs to be considered but a shape_proc stencil
!        Usually, the shape function radius is chosen to be the size of one BGM, but this 
!        is not necessarily always true. Hence new shape_proc padding:

BGMCells=0 
!Count BGMCells with Elements inside or adjacent and save their indices in BGMCellsArray
DO kBGM=BGMkmin, BGMkmax
  DO jBGM=BGMjmin, BGMjmax
    DO iBGM=BGMimin, BGMimax  
      iMin=MAX(iBGM-nShapePaddingX,BGMimin); iMax=MIN(iBGM+nShapePaddingX,BGMimax)
      jMin=MAX(jBGM-nShapePaddingY,BGMjmin); jMax=MIN(jBGM+nShapePaddingY,BGMjmax)
      kMin=MAX(kBGM-nShapePaddingZ,BGMkmin); kMax=MIN(kBGM+nShapePaddingZ,BGMkmax)
      IF (SUM(GEO%FIBGM(iMin:iMax,jMin:jMax,kMin:kMax)%nElem) .GT. 0) THEN
        ! debug here changed i,j,k to ibgm,jbgm,kbgm
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO !iBGM
  END DO !jBGM
END DO !kBGM

! now create a temporary array in which for all BGM Cells + ShapePadding the processes are saved 
! reason: this way, the ReducedBGM List only needs to be searched once and not once for each BGM Cell+Stencil

! first count the maximum number of procs that exist within each BGM cell (inkl. Shape Padding region)
ALLOCATE(CellProcNum(BGMimin-nShapePaddingX:BGMimax+nShapePaddingX, &
                     BGMjmin-nShapePaddingY:BGMjmax+nShapePaddingY, &
                     BGMkmin-nShapePaddingZ:BGMkmax+nShapePaddingZ))
CellProcNum = 0
Procs = 0 ! = maximum number of procs in one BGM cell
DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
  IF((ReducedBGMArray(j).GE.BGMimin-nShapePaddingX).AND.(ReducedBGMArray(j).LE.BGMimax+nShapePaddingX))THEN
    IF((ReducedBGMArray(j+1).GE.BGMjmin-nShapePaddingY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nShapePaddingY))THEN
      IF((ReducedBGMArray(j+2).GE.BGMkmin-nShapePaddingZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nShapePaddingZ))THEN !inside
        CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
        Procs = MAX(Procs, CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)))
      END IF
    END IF
  END IF
END DO
! allocate the temporary array
ALLOCATE(CellProcList(BGMimin-nShapePaddingX:BGMimax+nShapePaddingX, &
                      BGMjmin-nShapePaddingY:BGMjmax+nShapePaddingY, &
                      BGMkmin-nShapePaddingZ:BGMkmax+nShapePaddingZ, &
                      1:Procs))
CellProcList = -1

! fill array with proc numbers

CellProcNum = 0
j_offset = 0
DO CurrentProc = 0,PartMPI%nProcs-1
  DO j = 1+j_offset, ReducedNbrOfBGMCells(CurrentProc)*3-2+j_offset,3
    IF((ReducedBGMArray(j).GE.BGMimin-nShapePaddingX).AND.(ReducedBGMArray(j).LE.BGMimax+nShapePaddingX))THEN
      IF((ReducedBGMArray(j+1).GE.BGMjmin-nShapePaddingY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nShapePaddingY))THEN
        IF((ReducedBGMArray(j+2).GE.BGMkmin-nShapePaddingZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nShapePaddingZ))THEN
          CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
          CellProcList(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2), &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2))) = CurrentProc
        END IF
      END IF
    END IF
  END DO
  j_offset = j_offset + ReducedNbrOfBGMCells(CurrentProc)*3
END DO
! fill real array
DO Cell=0, BGMCells-1
  TempProcList=0
  Cell3=3*Cell
  DO kBGM = BGMCellsArray(Cell3+3)-nShapePaddingZ, BGMCellsArray(Cell3+3)+nShapePaddingZ
    DO jBGM = BGMCellsArray(Cell3+2)-nShapePaddingY, BGMCellsArray(Cell3+2)+nShapePaddingY
      DO iBGM = BGMCellsArray(Cell3+1)-nShapePaddingX, BGMCellsArray(Cell3+1)+nShapePaddingX
        DO m = 1,CellProcNum(iBGM,jBGM,kBGM)
          TempProcList(CellProcList(iBGM,jBGM,kBGM,m))=1       ! every proc that is within the stencil gets a 1
        END DO ! m
        ii = iBGM
      END DO !kBGM
      jj = jBGM
    END DO !jBGM
    kk = kBGM
  END DO !iBGM
  Procs=SUM(TempProcList)
  IF (Procs.NE.0) THEN
    ALLOCATE(GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(1:Procs+1))
    GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(1) = Procs
    j=2
    DO m=0,PartMPI%nProcs-1
      IF (TempProcList(m) .EQ. 1) THEN
        IF(.NOT.PartMPI%isMPINeighbor(m))THEN
          !IF(mode.EQ.2)THEN
          !  IPWRITE(UNIT_stdOut,*) ' Warning, something wrong with halo region'
          !  CALL abort(__STAMP__&
          !      , ' Something wrong with Halo region' )
          !END IF
          PartMPI%isMPINeighbor(m) = .true.
          PartMPI%nMPINeighbors=PartMPI%nMPINeighbors+1
        END IF
        GEO%FIBGM(ii-nShapePaddingX,jj-nShapePaddingY,kk-nShapePaddingZ)%ShapeProcs(j)=m
        j=j+1
      END IF
    END DO !m
  END IF
END DO !Cell

   !Compare own BGMCells and their Neighbors with ReducedBGMArray and save other Processes in BGM-Cells
   !--- JN: ReducedBGMArray contains data only from other MPI procs!
   !--- JN: BGMCellsArray contains in index triplets (i,k,l) all BGM cells containing elements from the local MPI proc
   !        plus the index triplets of BGM cells adjacent to cells containing elements from the local MPI proc

!   !--- JN: First identify only procs that share the exact same BGM cell as I (SharedProcs)
!   Procs = 0
!   CellProcList=-1
!   DO Cell=0, BGMCells-1
!     TempProcList=0
!     i = BGMCellsArray(Cell*3+1)
!     k = BGMCellsArray(Cell*3+2)
!     l = BGMCellsArray(Cell*3+3)
!     IF (GEO%FIBGM(i,k,l)%nElem.EQ.0) CYCLE
!     CurrentProc=0
!     m=2
!     DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
!       !--- JN: Slide CurrentProc to the MPI Proc that the currently checked BGMCell belongs to
!       DO WHILE (j .GT. SUM(ReducedNbrOfBGMCells(0: CurrentProc))*3 .AND. CurrentProc .LT. PMPIVAR%nProcs-1)
!         CurrentProc=CurrentProc+1
!       END DO
!       IF (i .EQ. ReducedBGMArray(j) .AND. k .EQ. ReducedBGMArray(j+1) .AND. l .EQ. ReducedBGMArray(j+2)) THEN
!         IF (m .GT. MaxShapeProcs) THEN
!           CALL abort(__STAMP__&
!                                'ERROR in Boundary_PIC.f90: Cellproclist can contain only MaxShapeProcs=',MaxShapeProcs,999.)
!         END IF
!         CellProcList(i,k,l,m)=CurrentProc
!         m=m+1
!         TempProcList(CurrentProc)=1
!       END IF
!     END DO !j
!     Procs=SUM(TempProcList)
!     ALLOCATE(GEO%FIBGM(i,k,l)%SharedProcs(1:Procs+1)) 
!     GEO%FIBGM(i,k,l)%SharedProcs(1) = Procs
!     j=2
!     DO m=0,PMPIVAR%nProcs-1
!       IF (TempProcList(m) .EQ. 1) THEN
!         GEO%FIBGM(i,k,l)%SharedProcs(j)=m
!         j=j+1
!       END IF
!     END DO !m
!   END DO !Cell


! ----------------------------------------------------------------!
!--- AS: Do it again for Paddingcells
DEALLOCATE(CellProcList)
DEALLOCATE(CellProcNum)
!--- JN: Determine required size of CellProcList array (hope this works, everytime I try to again understand this
!        shape function parallelization stuff, I get confused...)
!--- JN: But therefore we first have to refill BGMCellsArray to not only contain
!        cells with PIC%FastInitBGM%nElem.GT.0 but also those adjacent and the paddingcells to them!
BGMCells=0
DO kBGM=BGMkmin, BGMkmax
  DO jBGM=BGMjmin, BGMjmax
    DO iBGM=BGMimin, BGMimax  !Count BGMCells with Elements inside or adjacent and save their indices in BGMCellsArray
      iMin=MAX(iBGM-nPaddingCellsX,BGMimin); iMax=MIN(iBGM+nPaddingCellsX,BGMimax)
      jMin=MAX(jBGM-nPaddingCellsY,BGMjmin); jMax=MIN(jBGM+nPaddingCellsY,BGMjmax)
      kMin=MAX(kBGM-nPaddingCellsZ,BGMkmin); kMax=MIN(kBGM+nPaddingCellsZ,BGMkmax)
      IF (SUM(GEO%FIBGM(iMin:iMax,jMin:jMax,kMin:kMax)%nElem) .GT. 0) THEN
        BGMCellsArray(BGMCells*3+1)= iBGM
        BGMCellsArray(BGMCells*3+2)= jBGM
        BGMCellsArray(BGMCells*3+3)= kBGM
        BGMCells=BGMCells+1
      END IF
    END DO !iBGM
  END DO !jBGM
END DO !kBGM

! now create a temporary array in which for all BGM Cells + ShapePadding the processes are saved 
! reason: this way, the ReducedBGM List only needs to be searched once and not once for each BGM Cell+Stencil

! first count the maximum number of procs that exist within each BGM cell (inkl. Shape Padding region)
ALLOCATE(CellProcNum(BGMimin-nPaddingCellsX:BGMimax+nPaddingCellsX, &
                     BGMjmin-nPaddingCellsY:BGMjmax+nPaddingCellsY, &
                     BGMkmin-nPaddingCellsZ:BGMkmax+nPaddingCellsZ))
CellProcNum = 0
Procs = 0
DO j=1, SUM(ReducedNbrOfBGMCells)*3-2, 3
   IF((ReducedBGMArray(j).GE.BGMimin-nPaddingCellsX).AND.(ReducedBGMArray(j).LE.BGMimax+nPaddingCellsX))THEN
     IF((ReducedBGMArray(j+1).GE.BGMjmin-nPaddingCellsY).AND.(ReducedBGMArray(j+1).LE.BGMjmax+nPaddingCellsY))THEN
       IF((ReducedBGMArray(j+2).GE.BGMkmin-nPaddingCellsZ).AND.(ReducedBGMArray(j+2).LE.BGMkmax+nPaddingCellsZ))THEN
        CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
        Procs = MAX(Procs, CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)))
       END IF
     END IF
   END IF
END DO
! allocate the temporary array
ALLOCATE(CellProcList(BGMimin-nPaddingCellsX:BGMimax+nPaddingCellsX, &
                      BGMjmin-nPaddingCellsY:BGMjmax+nPaddingCellsY, &
                      BGMkmin-nPaddingCellsZ:BGMkmax+nPaddingCellsZ, &
                      1:Procs))
CellProcList = -1

! fill array with proc numbers

CellProcNum = 0
j_offset = 0
DO CurrentProc = 0,PartMPI%nProcs-1
  DO j = 1+j_offset, j_offset+ReducedNbrOfBGMCells(CurrentProc)*3-2,3
    CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) = &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2)) + 1
    CellProcList(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2), &
             CellProcNum(ReducedBGMArray(j),ReducedBGMArray(j+1),ReducedBGMArray(j+2))) = CurrentProc
  END DO
  j_offset = j_offset + ReducedNbrOfBGMCells(CurrentProc)*3
END DO

! fill real array
DO Cell=0, BGMCells-1
  TempProcList=0
  Cell3=3*Cell
  DO kBGM = BGMCellsArray(Cell3+3)-nPaddingCellsZ, BGMCellsArray(Cell3+3)+nPaddingCellsZ
    DO jBGM = BGMCellsArray(Cell3+2)-nPaddingCellsY, BGMCellsArray(Cell3+2)+nPaddingCellsY
      DO iBGM = BGMCellsArray(Cell3+1)-nPaddingCellsX, BGMCellsArray(Cell3+1)+nPaddingCellsX
        nEntry=CellProcNum(iBGM,jBGM,kBGM)
        DO m = 1,nEntry
          TempProcList(CellProcList(iBGM,jBGM,kBGM,m))=1       ! every proc that is within the stencil gets a 1
        END DO ! m
        ii = iBGM
      END DO !l
      jj = jBGM
    END DO !k
    kk = kBGM
  END DO !i
  Procs=SUM(TempProcList)
  IF (Procs.NE.0) THEN
    ALLOCATE(GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(1:Procs+1))
    GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(1) = Procs
    j=2
    DO m=0,PartMPI%nProcs-1
      IF (TempProcList(m) .EQ. 1) THEN
        GEO%FIBGM(ii-nPaddingCellsX,jj-nPaddingCellsY,kk-nPaddingCellsZ)%PaddingProcs(j)=m
        j=j+1
      END IF
    END DO !m
  END IF
END DO !Cell
DEALLOCATE(ReducedBGMArray, BGMCellsArray, CellProcList, GlobalBGMCellsArray, CellProcNum)
#endif /*MPI*/

END SUBROUTINE GetSFIBGM


SUBROUTINE AddHALOCellsToFIBGM(ElemToBGM,HaloElemToBGM)
!===================================================================================================================================
! remap all elements including halo-elements into FIBGM
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals!,            ONLY : UNIT_StdOut
USE MOD_ChangeBasis,                        ONLY:ChangeBasis2D
USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D,sVdm_Bezier
USE MOD_Particle_Surfaces_Vars,             ONLY:sVdm_Bezier
USE MOD_Mesh_Vars,                          ONLY:XCL_NGeo
USE MOD_Mesh_Vars,                          ONLY:nSides,NGeo
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems
USE MOD_Particle_Tracking_Vars,             ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,                 ONLY:PartElemToSide
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
USE MOD_Particle_Tracking_Vars,             ONLY:Distance,ListDistance
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!INTEGER,INTENT(IN)    :: mode
INTEGER,INTENT(IN)               :: ElemToBGM(1:6,1:PP_nElems)
INTEGER,INTENT(IN),OPTIONAL      :: HaloElemToBGM(1:6,PP_nElems+1:nTotalElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                          :: BGMimin,BGMimax,BGMjmin,BGMjmax,BGMkmin,BGMkmax,Allocstat
REAL                             :: xmin, xmax, ymin, ymax, zmin, zmax
INTEGER                          :: iBGM,jBGM,kBGM,SideID,iElem,ilocSide
INTEGER                          :: BGMCellXmax,BGMCellXmin
INTEGER                          :: BGMCellYmax,BGMCellYmin
INTEGER                          :: BGMCellZmax,BGMCellZmin
LOGICAL, ALLOCATABLE             :: ElementFound(:)
REAL                             :: BezierControlPoints3D_tmp(1:3,0:NGeo,0:NGeo)
INTEGER                          :: maxnBGMElems
!===================================================================================================================================


! current min,max
BGMimax=GEO%FIBGMimax
BGMimin=GEO%FIBGMimin
BGMjmax=GEO%FIBGMjmax
BGMjmin=GEO%FIBGMjmin
BGMkmax=GEO%FIBGMkmax
BGMkmin=GEO%FIBGMkmin

GEO%TFIBGMimax =GEO%FIBGMimax
GEO%TFIBGMimin =GEO%FIBGMimin
GEO%TFIBGMjmax =GEO%FIBGMjmax
GEO%TFIBGMjmin =GEO%FIBGMjmin
GEO%TFIBGMkmax =GEO%FIBGMkmax
GEO%TFIBGMkmin =GEO%FIBGMkmin

BGMCellXmax = BGMimax
BGMCellXmin = BGMimin
BGMCellYmax = BGMjmax
BGMCellYmin = BGMjmin
BGMCellZmax = BGMkmax
BGMCellZmin = BGMkmin

DO iElem=1,nTotalElems
  IF(iElem.LE.PP_nElems)THEN
    BGMCellXmin = ElemToBGM(1,iElem)
    BGMCellXmax = ElemToBGM(2,iElem)
    BGMCellYmin = ElemToBGM(3,iElem)
    BGMCellYmax = ElemToBGM(4,iElem)
    BGMCellZmin = ElemToBGM(5,iElem)
    BGMCellZmax = ElemToBGM(6,iElem)
  ELSE
    IF(.NOT.GEO%directions(1)) BGMCellXmin = HaloElemToBGM(1,iElem)
    IF(.NOT.GEO%directions(1)) BGMCellXmax = HaloElemToBGM(2,iElem)
    IF(.NOT.GEO%directions(2)) BGMCellYmin = HaloElemToBGM(3,iElem)
    IF(.NOT.GEO%directions(2)) BGMCellYmax = HaloElemToBGM(4,iElem)
    IF(.NOT.GEO%directions(3)) BGMCellZmin = HaloElemToBGM(5,iElem)
    IF(.NOT.GEO%directions(3)) BGMCellZmax = HaloElemToBGM(6,iElem)
  END IF

  BGMimin=MIN(BGMimin,BGMCellXmin)
  BGMimax=MAX(BGMimax,BGMCellXmax)
  BGMjmin=MIN(BGMjmin,BGMCellYmin)
  BGMjmax=MAX(BGMjmax,BGMCellYmax)
  BGMkmin=MIN(BGMkmin,BGMCellZmin)
  BGMkmax=MAX(BGMkmax,BGMCellZmax)

END DO ! iElem = nElems+1,nTotalElems

GEO%TFIBGMimax =BGMimax
GEO%TFIBGMimin =BGMimin
GEO%TFIBGMjmax =BGMjmax
GEO%TFIBGMjmin =BGMjmin
GEO%TFIBGMkmax =BGMkmax
GEO%TFIBGMkmin =BGMkmin

ALLOCATE(GEO%TFIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
,' ERROR in AddElemsToTFIBGM: Cannot allocate GEO%TFIBGM!')
END IF

ALLOCATE( ElementFound(1:nTotalElems) )
ElementFound = .FALSE.

! null number of elements per BGM-Cell
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
       GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM


!--- compute number of elements in each background cell
DO iElem=1,PP_nElems
  !--- find minimum and maximum BGM cell for current element
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(ElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(ElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(ElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(ElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(ElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(ElemToBGM(6,iElem),BGMkmax),BGMkmin)
  ! add ecurrent element to number of BGM-elems
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
         GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1
         ElementFound(iElem) = .TRUE.
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

DO iElem=PP_nElems+1,nTotalElems
  !--- find minimum and maximum BGM cell for current element
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(HaloElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(HaloElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(HaloElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(HaloElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(HaloElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(HaloElemToBGM(6,iElem),BGMkmax),BGMkmin)
  ! add ecurrent element to number of BGM-elems
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1
        ElementFound(iElem) = .TRUE.
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem


!--- allocate mapping variable and clean number for mapping (below)
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      IF(GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem.EQ.0) CYCLE
      ALLOCATE(GEO%TFIBGM(iBGM,jBGM,kBGM)%Element(1:GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem))
      GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- map elements to background cells
DO iElem=1,PP_nElems
  !--- find minimum and maximum BGM cell for current element
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(ElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(ElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(ElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(ElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(ElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(ElemToBGM(6,iElem),BGMkmax),BGMkmin)

  ! add current Element to BGM-Elem
  DO iBGM = BGMCellXmin,BGMCellXmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO kBGM = BGMCellZmin,BGMCellZmax
        GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1    
        GEO%TFIBGM(iBGM,jBGM,kBGM)%Element(GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem
DO iElem=PP_nElems+1,nTotalElems
  !--- find minimum and maximum BGM cell for current element
  ! here fancy stuff, because element could be wide out of element range
  BGMCellXmin = MIN(MAX(HaloElemToBGM(1,iElem),BGMimin),BGMimax)
  BGMCellXmax = MAX(MIN(HaloElemToBGM(2,iElem),BGMimax),BGMimin)
  BGMCellYmin = MIN(MAX(HaloElemToBGM(3,iElem),BGMjmin),BGMjmax)
  BGMCellYmax = MAX(MIN(HaloElemToBGM(4,iElem),BGMjmax),BGMjmin)
  BGMCellZmin = MIN(MAX(HaloElemToBGM(5,iElem),BGMkmin),BGMkmax)
  BGMCellZmax = MAX(MIN(HaloElemToBGM(6,iElem),BGMkmax),BGMkmin)

  ! add current Element to BGM-Elem
  DO iBGM = BGMCellXmin,BGMCellXmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO kBGM = BGMCellZmin,BGMCellZmax
        GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1    
        GEO%TFIBGM(iBGM,jBGM,kBGM)%Element(GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem


DO iElem=1,PP_nElems
  IF(.NOT.ElementFound(iElem))THEN
    !--- find minimum and maximum BGM cell for current element
    ! here fancy stuff, because element could be wide out of element range
    BGMCellXmin = ElemToBGM(1,iElem)
    BGMCellXmax = ElemToBGM(2,iElem)
    BGMCellYmin = ElemToBGM(3,iElem)
    BGMCellYmax = ElemToBGM(4,iElem)
    BGMCellZmin = ElemToBGM(5,iElem)
    BGMCellZmax = ElemToBGM(6,iElem)

    IPWRITE(UNIT_stdOut,*) ' TFIBGM , iElem'
    IPWRITE(UNIT_stdOut,*) 'xmin',GEO%xmin,xmin
    IPWRITE(UNIT_stdOut,*) 'xmax',GEO%xmax,xmax
    IPWRITE(UNIT_stdOut,*) 'ymin',GEO%ymin,ymin
    IPWRITE(UNIT_stdOut,*) 'ymax',GEO%ymax,ymax
    IPWRITE(UNIT_stdOut,*) 'zmin',GEO%zmin,zmin
    IPWRITE(UNIT_stdOut,*) 'zmax',GEO%zmax,zmax
    IPWRITE(UNIT_stdOut,*) ' BGM , iBGM'
    IPWRITE(UNIT_stdOut,*) 'xmin', BGMimin,BGMCellXmin
    IPWRITE(UNIT_stdOut,*) 'xmax', BGMimax,BGMCellXmax
    IPWRITE(UNIT_stdOut,*) 'ymin', BGMjmin,BGMCellYmin
    IPWRITE(UNIT_stdOut,*) 'ymax', BGMjmax,BGMCellYmax
    IPWRITE(UNIT_stdOut,*) 'zmin', BGMkmin,BGMCellYmin
    IPWRITE(UNIT_stdOut,*) 'zmax', BGMkmax,BGMCellYmax
    CALL abort(&
__STAMP__&
,' Element not located in FIBGM! iElem, myRank',iElem,REAL(PartMPI%MyRank))
  END IF
END DO ! iElem

DO iElem=PP_nElems+1,nTotalElems
  IF(.NOT.ElementFound(iElem))THEN
    !--- find minimum and maximum BGM cell for current element
    ! here fancy stuff, because element could be wide out of element range
    BGMCellXmin = HaloElemToBGM(1,iElem)
    BGMCellXmax = HaloElemToBGM(2,iElem)
    BGMCellYmin = HaloElemToBGM(3,iElem)
    BGMCellYmax = HaloElemToBGM(4,iElem)
    BGMCellZmin = HaloElemToBGM(5,iElem)
    BGMCellZmax = HaloElemToBGM(6,iElem)

    IPWRITE(UNIT_stdOut,*) ' TFIBGM , iElem'
    IPWRITE(UNIT_stdOut,*) 'xmin',GEO%xmin,xmin
    IPWRITE(UNIT_stdOut,*) 'xmax',GEO%xmax,xmax
    IPWRITE(UNIT_stdOut,*) 'ymin',GEO%ymin,ymin
    IPWRITE(UNIT_stdOut,*) 'ymax',GEO%ymax,ymax
    IPWRITE(UNIT_stdOut,*) 'zmin',GEO%zmin,zmin
    IPWRITE(UNIT_stdOut,*) 'zmax',GEO%zmax,zmax
    IPWRITE(UNIT_stdOut,*) ' BGM , iBGM'
    IPWRITE(UNIT_stdOut,*) 'xmin', BGMimin,BGMCellXmin
    IPWRITE(UNIT_stdOut,*) 'xmax', BGMimax,BGMCellXmax
    IPWRITE(UNIT_stdOut,*) 'ymin', BGMjmin,BGMCellYmin
    IPWRITE(UNIT_stdOut,*) 'ymax', BGMjmax,BGMCellYmax
    IPWRITE(UNIT_stdOut,*) 'zmin', BGMkmin,BGMCellYmin
    IPWRITE(UNIT_stdOut,*) 'zmax', BGMkmax,BGMCellYmax
    CALL abort(&
__STAMP__&
,' Element not located in FIBGM! iElem, myRank',iElem,REAL(PartMPI%MyRank))
  END IF
END DO ! iElem


DEALLOCATE(Elementfound)

! and get max number of bgm-elems
maxnBGMElems=0
DO kBGM = GEO%TFIBGMkmin,GEO%TFIBGMkmax
  DO jBGM = GEO%TFIBGMjmin,GEO%TFIBGMjmax
    DO iBGM = GEO%TFIBGMimin,GEO%TFIBGMimax
      !maxnBGMElems=MAX(maxnBGMElems,GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem)
      maxnBGMElems=MAX(maxnBGMElems,GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem)
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM
ALLOCATE(Distance    (1:maxnBGMElems) &
        ,ListDistance(1:maxnBGMElems) )


END SUBROUTINE AddHALOCellsToFIBGM


SUBROUTINE AddSimpleHALOCellsToFIBGM()
!===================================================================================================================================
! remap all elements including halo-elements into FIBGM
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals!,            ONLY : UNIT_StdOut
USE MOD_Particle_Mesh_Vars,                 ONLY:ElemBaryNGeo,ElemRadiusNGeo
USE MOD_Partilce_Periodic_BC,               ONLY:InitPeriodicBC
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems
USE MOD_Particle_Tracking_Vars,             ONLY:Distance,ListDistance
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!INTEGER,INTENT(IN)    :: mode
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                          :: BGMimin,BGMimax,BGMjmin,BGMjmax,BGMkmin,BGMkmax, ALLOCSTAT
REAL                             :: xmin, xmax, ymin, ymax, zmin, zmax
INTEGER                          :: iBGM,jBGM,kBGM,iElem
INTEGER                          :: BGMCellXmax,BGMCellXmin
INTEGER                          :: BGMCellYmax,BGMCellYmin
INTEGER                          :: BGMCellZmax,BGMCellZmin,maxnBGMElems
INTEGER                          :: nEntry
INTEGER, ALLOCATABLE             :: LocalCounter(:,:,:)
LOGICAL, ALLOCATABLE             :: ElementFound(:)
!===================================================================================================================================


! current min,max
BGMimax=GEO%FIBGMimax
BGMimin=GEO%FIBGMimin
BGMjmax=GEO%FIBGMjmax
BGMjmin=GEO%FIBGMjmin
BGMkmax=GEO%FIBGMkmax
BGMkmin=GEO%FIBGMkmin

GEO%TFIBGMimax =GEO%FIBGMimax
GEO%TFIBGMimin =GEO%FIBGMimin
GEO%TFIBGMjmax =GEO%FIBGMjmax
GEO%TFIBGMjmin =GEO%FIBGMjmin
GEO%TFIBGMkmax =GEO%FIBGMkmax
GEO%TFIBGMkmin =GEO%FIBGMkmin

IF(GEO%directions(1)) BGMCellXmax = BGMimax
IF(GEO%directions(1)) BGMCellXmin = BGMimin
IF(GEO%directions(2)) BGMCellYmax = BGMjmax
IF(GEO%directions(2)) BGMCellYmin = BGMjmin
IF(GEO%directions(3)) BGMCellZmax = BGMkmax
IF(GEO%directions(3)) BGMCellZmin = BGMkmin


! get new min max
DO iElem=PP_nElems+1,nTotalElems

  xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
  ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
  zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
  xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
  ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
  zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)
   
  IF(.NOT.GEO%directions(1)) BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
  IF(.NOT.GEO%directions(1)) BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
  IF(.NOT.GEO%directions(2)) BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
  IF(.NOT.GEO%directions(2)) BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
  IF(.NOT.GEO%directions(3)) BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
  IF(.NOT.GEO%directions(3)) BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))

  BGMimax=MAX(BGMimax,BGMCellXmax)
  BGMimin=MIN(BGMimin,BGMCellXmin)
  BGMjmax=MAX(BGMjmax,BGMCellYmax)
  BGMjmin=MIN(BGMjmin,BGMCellYmin)
  BGMkmax=MAX(BGMkmax,BGMCellZmax)
  BGMkmin=MIN(BGMkmin,BGMCellZmin)
END DO ! iElem = nElems+1,nTotalElems


GEO%TFIBGMimax =BGMimax
GEO%TFIBGMimin =BGMimin
GEO%TFIBGMjmax =BGMjmax
GEO%TFIBGMjmin =BGMjmin
GEO%TFIBGMkmax =BGMkmax
GEO%TFIBGMkmin =BGMkmin
ALLOCATE(GEO%TFIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
,' ERROR in AddElemsToTFIBGM: Cannot allocate GEO%TFIBGM!')
END IF
ALLOCATE(LocalCounter(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
,' ERROR in AddElemsToTFIBGM: Cannot allocate GEO%TFIBGM!')
END IF


ALLOCATE( ElementFound(1:nTotalElems) )
ElementFound = .FALSE.

DO iBGM = BGMimin,BGMimax
  DO jBGM = BGMjmin,BGMjmax
    DO kBGM = BGMkmin,BGMkmax
       !GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = 0
       LocalCounter(iBGM,jBGM,kBGM)=0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- compute number of elements in each background cell
DO iElem=1,nTotalElems
  ! get elem extension based on barycenter and radius
  xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
  ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
  zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
  xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
  ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
  zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)

  !--- find minimum and maximum BGM cell for current element
  IF(GEO%nPeriodicVectors.EQ.0)THEN
    ! same fancy stuff
    !BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    !BGMCellXmax = MIN(BGMCellXmax,BGMimax)
    !BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    !BGMCellXmin = MAX(BGMCellXmin,BGMimin)
    !BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    !BGMCellYmax = MIN(BGMCellYmax,BGMjmax)
    !BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    !BGMCellYmin = MAX(BGMCellYmin,BGMjmin)
    !BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    !BGMCellZmax = MIN(BGMCellZmax,BGMkmax)
    !BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    !BGMCellZmin = MAX(BGMCellZmin,BGMkmin)      
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MAX(MIN(BGMCellXmax,BGMimax),BGMimin)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MIN(MAX(BGMCellXmin,BGMimin),BGMimax)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MAX(MIN(BGMCellYmax,BGMjmax),BGMjmin)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MIN(MAX(BGMCellYmin,BGMjmin),BGMjmax)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MAX(MIN(BGMCellZmax,BGMkmax),BGMkmin)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MIN(MAX(BGMCellZmin,BGMkmin),BGMkmax)
  ELSE
    ! here fancy stuff, because element could be wide out of element range
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MAX(MIN(BGMCellXmax,BGMimax),BGMimin)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MIN(MAX(BGMCellXmin,BGMimin),BGMimax)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MAX(MIN(BGMCellYmax,BGMjmax),BGMjmin)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MIN(MAX(BGMCellYmin,BGMjmin),BGMjmax)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MAX(MIN(BGMCellZmax,BGMkmax),BGMkmin)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MIN(MAX(BGMCellZmin,BGMkmin),BGMkmax)
  END IF
  ! add ecurrent element to number of BGM-elems
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
         !GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1
         LocalCounter(iBGM,jBGM,kBGM) = LocalCounter(iBGM,jBGM,kBGM) + 1
         ElementFound(iElem) = .TRUE.
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

!--- allocate mapping variable and clean number for mapping (below)
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      nEntry = LocalCounter(iBGM,jBGM,kBGM)
      GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = nEntry
      ALLOCATE(GEO%TFIBGM(iBGM,jBGM,kBGM)%Element(1:nEntry))
      !GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = 0
      LocalCounter(iBGM,jBGM,kBGM) = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- map elements to background cells
DO iElem=1,nTotalElems
  ! get elem extension based on barycenter and radius
  xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
  ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
  zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
  xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
  ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
  zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)

  ! same as above
  IF(GEO%nPeriodicVectors.EQ.0)THEN
    ! still the fancy stuff
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MAX(MIN(BGMCellXmax,BGMimax),BGMimin)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MIN(MAX(BGMCellXmin,BGMimin),BGMimax)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MAX(MIN(BGMCellYmax,BGMjmax),BGMjmin)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MIN(MAX(BGMCellYmin,BGMjmin),BGMjmax)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MAX(MIN(BGMCellZmax,BGMkmax),BGMkmin)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MIN(MAX(BGMCellZmin,BGMkmin),BGMkmax)
  ELSE
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MAX(MIN(BGMCellXmax,BGMimax),BGMimin)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MIN(MAX(BGMCellXmin,BGMimin),BGMimax)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MAX(MIN(BGMCellYmax,BGMjmax),BGMjmin)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MIN(MAX(BGMCellYmin,BGMjmin),BGMjmax)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MAX(MIN(BGMCellZmax,BGMkmax),BGMkmin)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MIN(MAX(BGMCellZmin,BGMkmin),BGMkmax)
  END IF
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        !GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem + 1    
        !nEntry = GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem
        LocalCounter(iBGM,jBGM,kBGM) = LocalCounter(iBGM,jBGM,kBGM) + 1    
        nEntry = LocalCounter(iBGM,jBGM,kBGM)
        GEO%TFIBGM(iBGM,jBGM,kBGM)%Element(nEntry) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem


DO iElem=1,nTotalElems
  IF(.NOT.ElementFound(iElem))THEN
    ! get elem extension based on barycenter and radius
    xmin = ElemBaryNGeo(1,iElem) -ElemRadiusNGeo(iElem)
    ymin = ElemBaryNGeo(2,iElem) -ElemRadiusNGeo(iElem)
    zmin = ElemBaryNGeo(3,iElem) -ElemRadiusNGeo(iElem)
    xmax = ElemBaryNGeo(1,iElem) +ElemRadiusNGeo(iElem)
    ymax = ElemBaryNGeo(2,iElem) +ElemRadiusNGeo(iElem)
    zmax = ElemBaryNGeo(3,iElem) +ElemRadiusNGeo(iElem)


    IPWRITE(UNIT_stdOut,*) ' FIBGM , iElem'
    IPWRITE(UNIT_stdOut,*) 'xmin',GEO%xmin,xmin
    IPWRITE(UNIT_stdOut,*) 'xmax',GEO%xmax,xmax
    IPWRITE(UNIT_stdOut,*) 'ymin',GEO%ymin,ymin
    IPWRITE(UNIT_stdOut,*) 'ymax',GEO%ymax,ymax
    IPWRITE(UNIT_stdOut,*) 'zmin',GEO%zmin,zmin
    IPWRITE(UNIT_stdOut,*) 'zmax',GEO%zmax,zmax
    IPWRITE(UNIT_stdOut,*) ' BGM , iBGM'
    IPWRITE(UNIT_stdOut,*) 'xmin', BGMimin,CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    IPWRITE(UNIT_stdOut,*) 'xmax', BGMimax,CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    IPWRITE(UNIT_stdOut,*) 'ymin', BGMjmin,CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    IPWRITE(UNIT_stdOut,*) 'ymax', BGMjmax,CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    IPWRITE(UNIT_stdOut,*) 'zmin', BGMkmin,CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    IPWRITE(UNIT_stdOut,*) 'zmax', BGMkmax,CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    CALL abort(&
__STAMP__&
,' Element not located in FIBGM! iElem, myRank',iElem,REAL(PartMPI%MyRank))
  END IF
END DO ! iElem

DEALLOCATE(Elementfound)

! and get max number of bgm-elems
maxnBGMElems=0
DO kBGM = GEO%TFIBGMkmin,GEO%TFIBGMkmax
  DO jBGM = GEO%TFIBGMjmin,GEO%TFIBGMjmax
    DO iBGM = GEO%TFIBGMimin,GEO%TFIBGMimax
      !maxnBGMElems=MAX(maxnBGMElems,GEO%TFIBGM(iBGM,jBGM,kBGM)%nElem)
      maxnBGMElems=MAX(maxnBGMElems,LocalCounter(iBGM,jBGM,kBGM))
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM
ALLOCATE(Distance    (1:maxnBGMElems) &
        ,ListDistance(1:maxnBGMElems) )
DEALLOCATE(LocalCounter)

END SUBROUTINE AddSimpleHALOCellsToFIBGM


SUBROUTINE InitElemVolumes()
!===================================================================================================================================
! Calculate Element volumes for later use in particle routines
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals!,            ONLY : UNIT_StdOut
USE MOD_Mesh_Vars,          ONLY:nElems,sJ
USE MOD_Particle_Mesh_Vars, ONLY:GEO
USE MOD_Interpolation_Vars, ONLY:wGP
USE MOD_Particle_Vars,      ONLY:usevMPF
USE MOD_ReadInTools
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: iElem
INTEGER           :: i,j,k
INTEGER           :: ALLOCSTAT
REAL              :: J_N(1,0:PP_N,0:PP_N,0:PP_N)
!===================================================================================================================================
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT PARTICLE GEOMETRY INFORMATION (Element Volumes)...'
ALLOCATE(GEO%Volume(nElems),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
,'ERROR in InitParticleGeometry: Cannot allocate GEO%Volume!')
END IF
usevMPF = GETLOGICAL('Part-vMPF','.FALSE.')
IF(usevMPF) THEN
  ALLOCATE(GEO%DeltaEvMPF(nElems),STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
,'ERROR in InitParticleGeometry: Cannot allocate GEO%DeltaEvMPF!')
  END IF
  GEO%DeltaEvMPF(:) = 0.0
END IF
DO iElem=1,nElems
  !--- Calculate and save volume of element iElem
  J_N(1,0:PP_N,0:PP_N,0:PP_N)=1./sJ(:,:,:,iElem)
  GEO%Volume(iElem) = 0.
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    GEO%Volume(iElem) = GEO%Volume(iElem) + wGP(i)*wGP(j)*wGP(k)*J_N(1,i,j,k)
  END DO; END DO; END DO
END DO

GEO%LocalVolume=SUM(GEO%Volume)
#ifdef MPI
CALL MPI_ALLREDUCE(GEO%LocalVolume,GEO%MeshVolume,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,IERROR)
#else
GEO%MeshVolume=GEO%LocalVolume
#endif /*MPI*/

SWRITE(UNIT_StdOut,'(A,E18.8)') ' |           Total Volume of Mesh |                ', GEO%MeshVolume

!CALL MPI_BARRIER(MPI_COMM_WORLD,iError)


SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLE GEOMETRY INFORMATION (Element Volumes) DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')
END SUBROUTINE InitElemVolumes


SUBROUTINE ReShapeBezierSides()
!===================================================================================================================================
! Init of Particle mesh
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Mesh_Vars,     ONLY:nTotalBCSides,PartBCSideList,nTotalSides
USE MOD_Mesh_Vars,              ONLY:nSides,nBCSides,NGeo
USE MOD_Particle_Surfaces_Vars, ONLY:BezierControlPoints3D
USE MOD_Particle_Surfaces_Vars, ONLY:SideSlabNormals,SideSlabIntervals,BoundingBoxIsEmpty
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: ALLOCSTAT
INTEGER           :: iSide,nPeriodicSides,nOldBCSides,newBCSideID,BCInc,nHaloBCSides
REAL,ALLOCATABLE,DIMENSION(:,:,:)  :: DummySideSlabNormals                  ! normal vectors of bounding slab box
REAL,ALLOCATABLE,DIMENSION(:,:)    :: DummySideSlabIntervals               ! intervalls beta1, beta2, beta3
LOGICAL,ALLOCATABLE,DIMENSION(:)   :: DummyBoundingBoxIsEmpty
REAL,ALLOCATABLE                   :: DummyBezierControlPoints3D(:,:,:,:)                                
!===================================================================================================================================


nPeriodicSides=0
!DO iSide=nBCSides+1,nSides
!  IF(SidePeriodicType(iSide).NE.0) nPeriodicSides=nPeriodicSides+1
!END DO ! iSide

! now, shrink partbcsidelist
nOldBCSides  =nTotalBCSides
nTotalBCSides=nTotalBCSides-nSides+nBCSides
nTotalSides  =nTotalBCSides-nBCSides+nSides ! which is zero change


IF(nTotalBCSides.EQ.0) RETURN

! allocate & fill dummy
! BezierControlPoints3D
ALLOCATE(DummyBezierControlPoints3d(1:3,0:NGeo,0:NGeo,1:nOldBCSides))
IF (.NOT.ALLOCATED(DummyBezierControlPoints3d)) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
DummyBezierControlPoints3d=BezierControlPoints3d
DEALLOCATE(BezierControlPoints3D)
ALLOCATE(BezierControlPoints3d(1:3,0:NGeo,0:NGeo,1:nTotalBCSides),STAT=ALLOCSTAT)
BezierControlPoints3d=0.
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
! SideSlabNormals
ALLOCATE(DummySideSlabNormals(1:3,1:3,1:nOldBCSides))
IF (.NOT.ALLOCATED(DummySideSlabNormals)) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
DummySideSlabNormals=SideSlabNormals
DEALLOCATE(SideSlabNormals)
ALLOCATE(SideSlabNormals(1:3,1:3,1:nTotalBCSides),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
SideSlabNormals=0.
! SideSlabIntervals
ALLOCATE(DummySideSlabIntervals(1:6,1:nOldBCSides))
IF (.NOT.ALLOCATED(DummySideSlabIntervals)) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
DummySideSlabIntervals=SideSlabIntervals
DEALLOCATE(SideSlabIntervals)
ALLOCATE(SideSlabIntervals(1:6,1:nTotalBCSides),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
SideSlabIntervals=0.
! BoundingBoxIsEmpty
ALLOCATE(DummyBoundingBoxIsEmpty(1:nOldBCSides))
IF (.NOT.ALLOCATED(DummyBoundingBoxIsEmpty)) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
DummyBoundingBoxIsEmpty=BoundingBoxIsEmpty
DEALLOCATE(BoundingBoxIsEmpty)
ALLOCATE(BoundingBoxIsEmpty(1:nTotalBCSides),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__& !wunderschoen!!!
,'Could not allocate ElemIndex')
BoundingBoxIsEmpty=.FALSE.

BCInc=0
!DO iSide=1,nSides
newBCSideID=0
DO iSide=1,nBCSides
  newBCSideID=newBCSideID+1
  BezierControlPoints3d(1:3,0:NGeo,0:NGeo,newBCSideID) =DummyBezierControlPoints3D(1:3,0:NGeo,0:NGeo,iSide)
  SideSlabNormals          (1:3,1:3,          newBCSideID) =DummySideSlabNormals         (1:3,1:3,           iSide)
  SideSlabIntervals       (1:6,              newBCSideID) =DummySideSlabIntervals      (1:6,               iSide)
  BoundingBoxIsEmpty   (                  newBCSideID) =DummyBoundingBoxIsEmpty  (                   iSide)
END DO ! iSide

!newBCSideID=nBCSides
DO iSide=nSides+1,nOldBCSides
  newBCSideID=newBCSideID+1
  BezierControlPoints3d(1:3,0:NGeo,0:NGeo,newBCSideID) =DummyBezierControlPoints3D(1:3,0:NGeo,0:NGeo,iSide)
  SideSlabNormals          (1:3,1:3,          newBCSideID) =DummySideSlabNormals         (1:3,1:3,           iSide)
  SideSlabIntervals       (1:6,              newBCSideID) =DummySideSlabIntervals      (1:6,               iSide)
  BoundingBoxIsEmpty   (                  newBCSideID) =DummyBoundingBoxIsEmpty  (                   iSide)
END DO ! iSide

! create new mapping
SDEALLOCATE(PartBCSideList)
ALLOCATE(PartBCSideList(1:nTotalSides))
PartBCSideList=-1

DO iSide=1,nBCSides
  PartBCSideList(iSide)=iSide
END DO

nHaloBCSides=nBCSides
DO iSide=nSides+1,nTotalSides
  nHaloBCSides=nHaloBCSides+1
  PartBCSideList(iSide)=nHaloBCSides
END DO

! with periodic as bc sides
!BCInc=0
!DO iSide=1,nSides
!  IF((iSide.LE.nBCSides).OR.(SidePeriodicType(iSide).NE.0))THEN
!    IF(iSide.LE.nBCSides)THEN
!      newBCSideID=iSide
!    ELSE IF(SidePeriodicType(iSide).NE.0)THEN
!      BCInc=BCInc+1
!      newBCSideID=nBCSides+BCInc
!      PartBCSideList(iSide)=newBCSideID
!    END IF
!    BezierControlPoints3d(1:3,0:NGeo,0:NGeo,newBCSideID) =DummyBezierControlPoints3D(1:3,0:NGeo,0:NGeo,iSide)
!    SideSlabNormals          (1:3,1:3,          newBCSideID) =DummySideSlabNormals         (1:3,1:3,           iSide)
!    SideSlabIntervals       (1:6,              newBCSideID) =DummySideSlabIntervals      (1:6,               iSide)
!    BoundingBoxIsEmpty   (                  newBCSideID) =DummyBoundingBoxIsEmpty  (                   iSide)
!  END IF
!END DO ! iSide

! deallocate dummy buffer
DEALLOCATE(DummyBezierControlPoints3D)
DEALLOCATE(DummySideSlabNormals)
DEALLOCATE(DummySideSlabIntervals)
DEALLOCATE(DummyBoundingBoxIsEmpty)


END SUBROUTINE ReShapeBezierSides


SUBROUTINE MapRegionToElem() 
!----------------------------------------------------------------------------------------------------------------------------------!
! map a particle region to element
! check only element barycenter, nothing else
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Mesh_Vars,          ONLY:NbrOfRegions, RegionBounds,GEO,ElemBaryNgeo
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
 INTEGER                :: iElem, iRegions
!===================================================================================================================================
SDEALLOCATE(GEO%ElemToRegion)
ALLOCATE(GEO%ElemToRegion(1:PP_nElems)) 
GEO%ElemToRegion=0

DO iElem=1,PP_nElems
  DO iRegions=1,NbrOfRegions
    IF ((ElemBaryNGeo(1,iElem).LT.RegionBounds(1,iRegions)).OR.(ElemBaryNGEO(1,iElem).GE.RegionBounds(2,iRegions))) CYCLE
    IF ((ElemBaryNGeo(2,iElem).LT.RegionBounds(3,iRegions)).OR.(ElemBaryNGEO(2,iElem).GE.RegionBounds(4,iRegions))) CYCLE
    IF ((ElemBaryNGeo(3,iElem).LT.RegionBounds(5,iRegions)).OR.(ElemBaryNGEO(3,iElem).GE.RegionBounds(6,iRegions))) CYCLE
    IF (GEO%ElemToRegion(iElem).EQ.0) THEN
      GEO%ElemToRegion(iElem)=iRegions
    ELSE
      CALL abort(&
__STAMP__&
,'Defined regions are overlapping')
    END IF
  END DO ! iRegions=1,NbrOfRegions
END DO ! iElem=1,PP_nElems


END SUBROUTINE MapRegionToElem


SUBROUTINE PointToExactElement(X_In,Element,isInSide,doHalo)                                                         
!===================================================================================================================================
! this subroutine maps each particle to an element
! currently, a background mesh is used to find possible elements. if multiple elements are possible, the element with the smallest
! distance is picked as an initial guess
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Mesh_Vars,     ONLY:Geo
USE MOD_Particle_Mesh_Vars,     ONLY:epsOneCell,ElemBaryNGeo
USE MOD_Particle_Tracking_Vars, ONLY:ListDistance,Distance
USE MOD_Eval_xyz,               ONLY:eval_xyz_elemcheck
USE MOD_Utils,                  ONLY:InsertionSort !BubbleSortID
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE                                                                                   
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
REAL,INTENT(IN)                   :: X_in(3)
LOGICAL,INTENT(IN)                :: doHalo
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
LOGICAL,INTENT(OUT)                :: isInside
INTEGER,INTENT(OUT)                :: Element
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                           :: iBGMElem,nBGMElems, ElemID, CellX,CellY,CellZ
!-----------------------------------------------------------------------------------------------------------------------------------
REAL                              :: xi(1:3)
!REAL,PARAMETER                    :: eps=1e-8 ! same value as in eval_xyz_elem
!REAL,PARAMETER                    :: eps2=1e-3
!REAL                              :: epsOne,OneMeps
!===================================================================================================================================

!epsOne=1.0+epsInCell
!OneMeps=1.0-eps
isInside = .FALSE.
IF ( (X_in(1).LT.GEO%xmin).OR.(X_in(1).GT.GEO%xmax).OR. &
     (X_in(2).LT.GEO%ymin).OR.(X_in(2).GT.GEO%ymax).OR. &
     (X_in(3).LT.GEO%zmin).OR.(X_in(3).GT.GEO%zmax)) THEN
   RETURN
END IF

! --- get background mesh cell of particle
CellX = CEILING((X_in(1)-GEO%xminglob)/GEO%FIBGMdeltas(1)) 
CellX = MIN(GEO%FIBGMimax,CellX)                             
CellY = CEILING((X_in(2)-GEO%yminglob)/GEO%FIBGMdeltas(2))
CellY = MIN(GEO%FIBGMjmax,CellY) 
CellZ = CEILING((X_in(3)-GEO%zminglob)/GEO%FIBGMdeltas(3))
CellZ = MIN(GEO%FIBGMkmax,CellZ)

!--- check all cells associated with this beckground mesh cell
nBGMElems=GEO%FIBGM(CellX,CellY,CellZ)%nElem

! get closest element barycenter
Distance=-1.
ListDistance=0
DO iBGMElem = 1, nBGMElems
  ElemID = GEO%FIBGM(CellX,CellY,CellZ)%Element(iBGMElem)
  Distance(iBGMElem)=(X_in(1)-ElemBaryNGeo(1,ElemID))*(X_in(1)-ElemBaryNGeo(1,ElemID)) &
                    +(X_in(2)-ElemBaryNGeo(2,ElemID))*(X_in(2)-ElemBaryNGeo(2,ElemID)) &
                    +(X_in(3)-ElemBaryNGeo(3,ElemID))*(X_in(3)-ElemBaryNGeo(3,ElemID)) 
  Distance(iBGMElem)=SQRT(Distance(iBGMElem))
  ListDistance(iBGMElem)=ElemID
END DO ! nBGMElems

IF(nBGMElems.GT.1) CALL InsertionSort(Distance(1:nBGMElems),ListDistance(1:nBGMElems),nBGMElems)
!print*,'after',Distance,ListDistance

! loop through sorted list and start by closest element  
Element=-1
DO iBGMElem=1,nBGMElems
  ElemID=ListDistance(iBGMElem)
  IF(.NOT.DoHALO)THEN
    IF(ElemID.GT.PP_nElems) CYCLE
  END IF
  CALL Eval_xyz_elemcheck(X_in(1:3),xi,ElemID)
  IF(ALL(ABS(Xi).LE.epsOneCell(ElemID))) THEN ! particle inside
    isInSide=.TRUE.
    Element=ElemID
    EXIT
  END IF
END DO ! iBGMElem

END SUBROUTINE PointToExactElement


SUBROUTINE BuildElementOrigin()
!================================================================================================================================
! compute the element origin at xi=(0,0,0)^T and set it as ElemBaryNGeo
!================================================================================================================================
USE MOD_Globals!,                  ONLY:CROSS
USE MOD_Preproc
USE MOD_Mesh_Vars,                ONLY:NGeo,XCL_NGeo,wBaryCL_NGeo,XiCL_NGeo
USE MOD_Particle_Mesh_Vars,       ONLY:ElemBaryNGeo
USE MOD_Basis,                    ONLY:LagrangeInterpolationPolys
USE MOD_Eval_xyz,                 ONLY:Eval_XYZ_Poly
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!--------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!--------------------------------------------------------------------------------------------------------------------------------
!OUTPUT VARIABLES
!--------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                 :: iElem,i,j,k
REAL                    :: Xi(3),XPos(3),buf
REAL                    :: Lag(1:3,0:NGeo)
!================================================================================================================================

ElemBaryNGeo=0.
DO iElem=1,PP_nElems
  ! evaluate the polynomial at origin
  Xi=(/0.0,0.0,0.0/)
  CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
  CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
  CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
  xPos=0.
  DO k=0,NGeo
    DO j=0,NGeo
      buf=Lag(2,j)*Lag(3,k)
      DO i=0,NGeo
        xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*buf
      END DO !i=0,NGeo
    END DO !j=0,NGeo
  END DO !k=0,NGeo
  ElemBaryNGeo(:,iElem)=xPos
END DO ! iElem

END SUBROUTINE BuildElementOrigin


SUBROUTINE BuildElementBasis()
!================================================================================================================================
! build the element local basis system 
! origin is located at xi=(0,0,0)^T
! each local coord system is pointing to an element side
!================================================================================================================================
USE MOD_Globals!,                  ONLY:CROSS
USE MOD_Preproc
USE MOD_Mesh_Vars,                ONLY:NGeo,XCL_NGeo,wBaryCL_NGeo,XiCL_NGeo
USE MOD_Particle_Surfaces_Vars,   ONLY:BezierControlPoints3D
USE MOD_Basis,                    ONLY:DeCasteljauInterpolation
USE MOD_Particle_Mesh_Vars,       ONLY:XiEtaZetaBasis,ElemBaryNGeo,slenXiEtaZetaBasis,ElemRadiusNGeo,ElemRadius2NGeo
USE MOD_Particle_Tracking_Vars,   ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,       ONLY:nTotalElems,PartElemToSide
USE MOD_Basis,                    ONLY:LagrangeInterpolationPolys
USE MOD_PICDepo_Vars,             ONLY:DepositionType,r_sf,ElemRadius2_sf
USE MOD_Eval_xyz,                 ONLY:Eval_XYZ_Poly
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!--------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!--------------------------------------------------------------------------------------------------------------------------------
!OUTPUT VARIABLES
!--------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                 :: iElem,SideID,i,j,k,ilocSide, ALLOCSTAT
REAL                    :: Xi(3),XPos(3),Radius
REAL                    :: Lag(1:3,0:NGeo)
!================================================================================================================================

ElemRadiusNGeo=0.
DO iElem=1,nTotalElems
  ! get point on each side 
  IF((iElem.LE.PP_nElems).OR.(DoRefMapping))THEN
    ! xi plus
    Xi=(/1.0,0.0,0.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,1,iElem)=xPos
    ! eta plus
    Xi=(/0.0,1.0,0.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,2,iElem)=xPos
    ! zeta plus
    Xi=(/0.0,0.0,1.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,3,iElem)=xPos
    ! xi minus
    Xi=(/-1.0,0.0,0.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,4,iElem)=xPos
    ! eta minus
    Xi=(/0.0,-1.0,0.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,5,iElem)=xPos
    ! zeta minus
    Xi=(/0.0,0.0,-1.0/)
    CALL LagrangeInterpolationPolys(Xi(1),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(1,:))
    CALL LagrangeInterpolationPolys(Xi(2),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(2,:))
    CALL LagrangeInterpolationPolys(Xi(3),NGeo,XiCL_NGeo,wBaryCL_NGeo,Lag(3,:))
    xPos=0.
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=xPos+XCL_NGeo(:,i,j,k,iElem)*Lag(1,i)*Lag(2,j)*Lag(3,k)
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
    XiEtaZetaBasis(1:3,6,iElem)=xPos
  ELSE ! compute particle position in physical space
    Xi=(/0.0,0.0,0.0/)
    SideID = PartElemToSide(1,XI_PLUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,1,iElem))
    SideID = PartElemToSide(1,ETA_PLUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,2,iElem))
    SideID = PartElemToSide(1,ZETA_PLUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,3,iElem))
    SideID = PartElemToSide(1,XI_MINUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,4,iElem))
    SideID = PartElemToSide(1,ETA_MINUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,5,iElem))
    SideID = PartElemToSide(1,ZETA_MINUS,iElem)
    CALL DeCasteljauInterpolation(NGeo,Xi(1:2),SideID,XiEtaZetaBasis(1:3,6,iElem))
  END IF ! no ref mapping
  ! compute vector from each barycenter to sidecenter
  XiEtaZetaBasis(:,1,iElem)=XiEtaZetaBasis(:,1,iElem)-ElemBaryNGeo(:,iElem)
  XiEtaZetaBasis(:,2,iElem)=XiEtaZetaBasis(:,2,iElem)-ElemBaryNGeo(:,iElem)
  XiEtaZetaBasis(:,3,iElem)=XiEtaZetaBasis(:,3,iElem)-ElemBaryNGeo(:,iElem)
  XiEtaZetaBasis(:,4,iElem)=XiEtaZetaBasis(:,4,iElem)-ElemBaryNGeo(:,iElem)
  XiEtaZetaBasis(:,5,iElem)=XiEtaZetaBasis(:,5,iElem)-ElemBaryNGeo(:,iElem)
  XiEtaZetaBasis(:,6,iElem)=XiEtaZetaBasis(:,6,iElem)-ElemBaryNGeo(:,iElem)
  ! compute length
  slenXiEtaZetaBasis(1,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,1,iElem),XiEtaZetaBasis(:,1,iElem))
  slenXiEtaZetaBasis(2,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,2,iElem),XiEtaZetaBasis(:,2,iElem))
  slenXiEtaZetaBasis(3,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,3,iElem),XiEtaZetaBasis(:,3,iElem))
  slenXiEtaZetaBasis(4,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,4,iElem),XiEtaZetaBasis(:,4,iElem))
  slenXiEtaZetaBasis(5,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,5,iElem),XiEtaZetaBasis(:,5,iElem))
  slenXiEtaZetaBasis(6,iElem)=1.0/DOT_PRODUCT(XiEtaZetaBasis(:,6,iElem),XiEtaZetaBasis(:,6,iElem))

  Radius=0.
  IF(DoRefMapping)THEN ! thats not the bounding box, caution, this box is to small!
    DO k=0,NGeo
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=XCL_NGeo(:,i,j,k,iElem)-ElemBaryNGeo(:,iElem)
          Radius=MAX(Radius,SQRT(DOT_PRODUCT(xPos,xPos)))      
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO !k=0,NGeo
  ELSE
    IF(iElem.GT.PP_nElems) CYCLE
    DO ilocSide=1,6
      SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
      IF(SideID.EQ.-1) CYCLE
      DO j=0,NGeo
        DO i=0,NGeo
          xPos=BezierControlPoints3D(:,i,j,SideID)-ElemBaryNGeo(:,iElem)
          Radius=MAX(Radius,SQRT(DOT_PRODUCT(xPos,xPos)))      
        END DO !i=0,NGeo
      END DO !j=0,NGeo
    END DO ! ilocSide
  END IF
  !ElemRadiusNGeo(iElem)=Radius
  ! elem radius containts 10% tolerance because we are not using the beziercontrolpoints
  ElemRadiusNGeo(iElem)=Radius
  IF(DoRefMapping)THEN
    !ElemRadius2NGeo(iElem)=(Radius*1.10)*(Radius*1.10)
    ElemRadius2NGeo(iElem)=(Radius*1.02)*(Radius*1.02)
  ELSE
    ElemRadius2NGeo(iElem)=Radius*Radius
  END IF
END DO ! iElem

IF (TRIM(DepositionType).EQ.'shape_function')THEN
  ALLOCATE(ElemRadius2_sf(1:PP_nElems),STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__ &
,' Cannot allocate ElemRadius2_sf!')
  DO iElem=1,PP_nElems
    ElemRadius2_sf(iElem)=(ElemRadiusNGeo(iElem)+r_sf)*(ElemRadiusNGeo(iElem)+r_sf)
  END DO ! iElem=1,PP_nElems
END IF


END SUBROUTINE BuildElementBasis


SUBROUTINE MapElemToFIBGM() 
!----------------------------------------------------------------------------------------------------------------------------------!
! here, the FIBGM range for each element is stored
! short list for intersection tracking, longer list for ref mapping tracking
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Mesh_Vars,     ONLY:GEO,nTotalElems
USE MOD_Mesh_Vars,              ONLY:XCL_NGeo
USE MOD_Particle_Tracking_Vars, ONLY:DoRefMapping
!----------------------------------------------------------------------------------------------------------------------------------!
! insert modules here
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: ALLOCSTAT,iElem,lastElem
REAL              :: xmin,ymin,zmin,xmax,ymax,zmax
INTEGER           :: BGMimax,BGMimin,BGMjmax,BGMjmin,BGMkmax,BGMkmin
INTEGER           :: BGMCellXmax,BGMCellXmin,BGMCellYmax,BGMCellYmin,BGMCellZmax,BGMCellZmin
!===================================================================================================================================

!IF(.NOT.DoRefMapping) RETURN

IF(DoRefMapping) THEN
  LastElem=nTotalElems
ELSE
  LastElem=PP_nElems
END IF

ALLOCATE(GEO%ElemToFIBGM(1:6,1:LastElem),STAT=ALLOCSTAT )
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__&
,'  Cannot allocate GEO%ElemToFIBGM!')

! because I copy and past
BGMimax=GEO%FIBGMimax
BGMimin=GEO%FIBGMimin
BGMjmax=GEO%FIBGMjmax
BGMjmin=GEO%FIBGMjmin
BGMkmax=GEO%FIBGMkmax
BGMkmin=GEO%FIBGMkmin



DO iElem=1,LastElem
  xmin=HUGE(1.)
  ymin=HUGE(1.)
  zmin=HUGE(1.)
  xmax=-HUGE(1.)
  ymax=-HUGE(1.)
  zmax=-HUGE(1.)
  xmin=MIN(xmin,MINVAL(XCL_NGeo(1,:,:,:,iElem)))
  xmax=MAX(xmax,MAXVAL(XCL_NGeo(1,:,:,:,iElem)))
  ymin=MIN(ymin,MINVAL(XCL_NGeo(2,:,:,:,iElem)))
  ymax=MAX(ymax,MAXVAL(XCL_NGeo(2,:,:,:,iElem)))
  zmin=MIN(zmin,MINVAL(XCL_NGeo(3,:,:,:,iElem)))
  zmax=MAX(zmax,MAXVAL(XCL_NGeo(3,:,:,:,iElem)))
  !--- find minimum and maximum BGM cell for current element
  IF(GEO%nPeriodicVectors.EQ.0)THEN
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MIN(BGMCellXmax,BGMimax)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MAX(BGMCellXmin,BGMimin)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MIN(BGMCellYmax,BGMjmax)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MAX(BGMCellYmin,BGMjmin)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MIN(BGMCellZmax,BGMkmax)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MAX(BGMCellZmin,BGMkmin)      
  ELSE
    ! here fancy stuff, because element could be wide out of element range
    BGMCellXmax = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmax = MAX(MIN(BGMCellXmax,BGMimax),BGMimin)
    BGMCellXmin = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
    BGMCellXmin = MIN(MAX(BGMCellXmin,BGMimin),BGMimax)
    BGMCellYmax = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmax = MAX(MIN(BGMCellYmax,BGMjmax),BGMjmin)
    BGMCellYmin = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
    BGMCellYmin = MIN(MAX(BGMCellYmin,BGMjmin),BGMjmax)
    BGMCellZmax = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmax = MAX(MIN(BGMCellZmax,BGMkmax),BGMkmin)
    BGMCellZmin = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
    BGMCellZmin = MIN(MAX(BGMCellZmin,BGMkmin),BGMkmax)
  END IF
  GEO%ElemToFIBGM(1,iElem)=BGMCellXmin  
  GEO%ElemToFIBGM(3,iElem)=BGMCellYmin  
  GEO%ElemToFIBGM(5,iElem)=BGMCellZmin  

  GEO%ElemToFIBGM(2,iElem)=BGMCellXmax  
  GEO%ElemToFIBGM(4,iElem)=BGMCellYmax  
  GEO%ElemToFIBGM(6,iElem)=BGMCellZmax  
END DO ! iElem=1,nTotalElems

END SUBROUTINE MapElemToFIBGM


SUBROUTINE CountPartsPerElem()
!===================================================================================================================================
! Deallocate arrays
!===================================================================================================================================
! MODULES
USE MOD_LoadBalance_Vars,        ONLY: nPartsPerElem
USE MOD_Particle_Vars,           ONLY: PDM,PEM
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: iPart, ElemID
!===================================================================================================================================

DO iPart=1,PDM%ParticleVecLength
  IF(PDM%ParticleInside(iPart))THEN
    ElemID = PEM%Element(iPart)
    nPartsPerElem(ElemID)=nPartsPerElem(ElemID)+1
  END IF
END DO ! iPart=1,PDM%ParticleVecLength

END SUBROUTINE CountPartsPerElem


SUBROUTINE CheckIfCurvedElem(IsCurved,XCL_NGeo)
!===================================================================================================================================
! check if element is curved
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Mesh_Vars,             ONLY:NGeo,Vdm_CLNGeo1_CLNGeo
USE MOD_ChangeBasis,           ONLY:changeBasis3D
USE MOD_Globals,               ONLY:ALMOSTEQUAL
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
REAL,INTENT(IN)      :: XCL_NGeo(1:3,0:NGeo,0:NGeo,0:NGeo)
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
LOGICAL              :: IsCurved
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                 :: XCL_NGeo1(1:3,0:1,0:1,0:1)
REAL                 :: XCL_NGeoNew(1:3,0:NGeo,0:NGeo,0:NGeo)
INTEGER              :: NGeo3
!===================================================================================================================================

IsCurved=.FALSE.

! fill dummy
XCL_NGeo1(1:3,0,0,0) = XCL_NGeo(1:3, 0  , 0  , 0  )
XCL_NGeo1(1:3,1,0,0) = XCL_NGeo(1:3,NGeo, 0  , 0  )
XCL_NGeo1(1:3,0,1,0) = XCL_NGeo(1:3, 0  ,NGeo, 0  )
XCL_NGeo1(1:3,1,1,0) = XCL_NGeo(1:3,NGeo,NGeo, 0  )
XCL_NGeo1(1:3,0,0,1) = XCL_NGeo(1:3, 0  , 0  ,NGeo)
XCL_NGeo1(1:3,1,0,1) = XCL_NGeo(1:3,NGeo, 0  ,NGeo)
XCL_NGeo1(1:3,0,1,1) = XCL_NGeo(1:3, 0  ,NGeo,NGeo)
XCL_NGeo1(1:3,1,1,1) = XCL_NGeo(1:3,NGeo,NGeo,NGeo)

CALL ChangeBasis3D(3,1,NGeo,Vdm_CLNGeo1_CLNGeo,XCL_NGeo1,XCL_NGeoNew)
NGeo3=(NGeo+1)*(NGeo+1)*(NGeo+1)

! check 3D points
CALL PointsEqual(NGeo3,XCL_NGeoNew,XCL_NGeo,IsCurved)

IF(.NOT.IsCurved)THEN
  ! set all elem sides to blabla
END IF

END SUBROUTINE CheckIfCurvedElem


SUBROUTINE PointsEqual(N,Points1,Points2,IsNotEqual) 
!===================================================================================================================================
! compute the distance between two data sets
!===================================================================================================================================
! MODULES                                                                                                                          !
!USE MOD_Globals,    ONLY:AlmostEqual
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES 
INTEGER,INTENT(IN)        :: N
REAL,INTENT(IN)           :: Points1(1:3,1:N)
REAL,INTENT(IN)           :: Points2(1:3,1:N)
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
LOGICAL                   :: IsNotEqual
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: i
!===================================================================================================================================

IsNotEqual=.FALSE.

DO i=1,N
  IF( ABS(Points1(1,i)-Points2(1,i)).GT.1e-14 .OR. & 
      ABS(Points1(2,i)-Points2(2,i)).GT.1e-14 .OR. & 
      ABS(Points1(3,i)-Points2(3,i)).GT.1e-14 ) THEN
    IsNotEqual=.TRUE.
    RETURN
  END IF
END DO ! i=0,N

END SUBROUTINE PointsEqual

SUBROUTINE InitElemBoundingBox() 
!===================================================================================================================================
! init of tight elem bounding box, constructed via beziercontrolpoints
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Mesh_Vars,               ONLY:nElems,NGeo
USE MOD_Particle_Surfaces,       ONLY:GetElemSlabNormalsAndIntervals
#ifdef MPI
USE MOD_Particle_MPI,            ONLY:ExchangeBezierControlPoints3d
#endif /*MPI*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: iElem
!===================================================================================================================================

#ifdef PARTICLES
#ifdef MPI
! first communicate the bezierControlPoints (slave information is missing)
CALL ExchangeBezierControlPoints3D()
#endif /*MPI*/
DO iElem=1,nElems
 CALL GetElemSlabNormalsAndIntervals(NGeo,iElem)
END DO !iElem=1,nElems
#endif /*PARTICLES*/


END SUBROUTINE InitElemBoundingBox


SUBROUTINE InsideElemBoundingBox(ParticlePosition,ElemID,InSide)
!================================================================================================================================
! check is the particles is inside the bounding box, return TRUE/FALSE
!================================================================================================================================
USE MOD_Globals_Vars
USE MOD_Particle_Surfaces_Vars,  ONLY:ElemSlabNormals,ElemSlabIntervals
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!--------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,DIMENSION(3),INTENT(IN)         :: ParticlePosition
INTEGER,INTENT(IN)                   :: ElemID
!--------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
LOGICAL,INTENT(OUT)                  :: Inside
!--------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                                 :: x,y,z,P(3)
!================================================================================================================================
P=ParticlePosition-ElemSlabNormals(1:3,0,ElemID)
! y is perpendicular to xi & eta directions --> check first, smallest intervall
y=DOT_PRODUCT(P,ElemSlabNormals(:,2,ElemID))
!IF((y.LT.ElemSlabIntervals(3,ElemID)-epsilontol).OR.(y.GT.ElemSlabIntervals(4,ElemID)+epsilontol))THEN
IF((y.LT.ElemSlabIntervals(3,ElemID)).OR.(y.GT.ElemSlabIntervals(4,ElemID)))THEN
  Inside=.FALSE.
  RETURN
END IF
! than xi
x=DOT_PRODUCT(P,ElemSlabNormals(:,1,ElemID))
!IF((x.LT.ElemSlabIntervals(1,ElemID)-epsilontol).OR.(x.GT.ElemSlabIntervals(2,ElemID)+epsilontol))THEN
IF((x.LT.ElemSlabIntervals(1,ElemID)).OR.(x.GT.ElemSlabIntervals(2,ElemID)))THEN
  Inside=.FALSE.
  RETURN
END IF
! than eta
z=DOT_PRODUCT(P,ElemSlabNormals(:,3,ElemID))
!IF((z.LT.ElemSlabIntervals(5,ElemID)-epsilontol).OR.(z.GT.ElemSlabIntervals(6,ElemID)+epsilontol))THEN
IF((z.LT.ElemSlabIntervals(5,ElemID)).OR.(z.GT.ElemSlabIntervals(6,ElemID)))THEN
  Inside=.FALSE.
  RETURN
END IF
Inside=.TRUE.
END SUBROUTINE InsideElemBoundingBox


SUBROUTINE GetElemAndSideType() 
!===================================================================================================================================
! get the element and side type of each element,depending on the 
! used tracking method
! 1) Get Elem Type
! 2) Get Side Type
! 3) Halo sides
! 4) Add BC and Halo-BC sides in halo_eps distance to a certain element (DoRefMapping=F)
! 5) build epsOneCell for each element
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Tracking_Vars,             ONLY:DoRefMapping
USE MOD_Mesh_Vars,                          ONLY:CurvedElem,XCL_NGeo,nGlobalElems,nSides,SideID_minus_upper,NGeo,nBCSides,sJ
USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D,BoundingBoxIsEmpty,SideType,SideNormVec,SideDistance
USE MOD_Particle_Mesh_Vars,                 ONLY:nTotalSides,IsBCElem,nTotalBCSides,nTotalElems,nTotalBCElems
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
USE MOD_Particle_Mesh_Vars,                 ONLY:PartElemToSide,BCElem,PartSideToElem,PartBCSideList,nTotalBCSides,GEO
USE MOD_Particle_MPI_Vars,                  ONLY:halo_eps,halo_eps2
USE MOD_Mesh_Vars,                          ONLY:CurvedElem,XCL_NGeo,nGlobalElems,Vdm_CLNGeo1_CLNGeo,BC
USE MOD_ChangeBasis,                        ONLY:changeBasis3D
USE MOD_Particle_Mesh_Vars,                 ONLY:RefMappingEps,epsOneCell
#ifdef MPI
!USE MOD_Particle_MPI_HALO,                  ONLY:WriteParticleMappingPartitionInformation
USE MOD_Particle_MPI_HALO,                  ONLY:WriteParticlePartitionInformation
#endif /*MPI*/
#if ((PP_TimeDiscMethod!=1) && (PP_TimeDiscMethod!=2) && (PP_TimeDiscMethod!=6))  /* RK3 and RK4 only */
USE MOD_Mesh_Vars,                          ONLY:XCL_NGeo
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                                  :: iElem, nCurvedElems,nCurvedElemsTot
INTEGER                                  :: iSide,p,q, nDummy,SideID,TrueSideID,ilocSide,nBCElems,nBCelemsTot
INTEGER                                  :: nPlanarRectangular, nPlanarNonRectangular,nPlanarCurved,nBilinear,nCurved
INTEGER                                  :: nPlanarRectangularTot, nPlanarNonRectangularTot,nPlanarCurvedTot,nBilinearTot,nCurvedTot
INTEGER                                  :: nCurvedElemsHalo,nLinearElems,nLinearElemsHalo,nBCElemsHalo
#ifdef MPI
INTEGER                                  :: nPlanarRectangularHalo, nPlanarNonRectangularHalo,nPlanarCurvedHalo, &
                                            nBilinearHalo,nCurvedHalo
#endif /*MPI*/
INTEGER                                  :: nSideCount, BCSideID,  s,r
INTEGER,ALLOCATABLE                      :: SideIndex(:)
REAL,DIMENSION(1:3)                      :: v1,v2,NodeX,v3
REAL                                     :: length,eps
LOGICAL                                  :: isLinear,leave
#if (PP_TimeDiscMethod!=1)&&(PP_TimeDiscMethod!=2)&&(PP_TimeDiscMethod!=6)&&((PP_TimeDiscMethod<501 || PP_TimeDiscMethod>506))
REAL,DIMENSION(1:3,0:NGeo,0:NGeo) :: xNodes
#endif
#if (PP_TimeDiscMethod==1)||(PP_TimeDiscMethod==2)||(PP_TimeDiscMethod==6)||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=506)
INTEGER                                 :: BCSideID2
#endif
LOGICAL,ALLOCATABLE                     :: SideIsDone(:)
REAL                                    :: XCL_NGeo1(1:3,0:1,0:1,0:1)
REAL                                    :: XCL_NGeoNew(1:3,0:NGeo,0:NGeo,0:NGeo)
INTEGER                                 :: NGeo3,NGeo2, nLoop
REAL                                    :: XCL_NGeoSideNew(1:3,0:NGeo,0:NGeo),scaleJ
REAL                                    :: Distance ,maxScaleJ
REAL                                    :: XCL_NGeoSideOld(1:3,0:NGeo,0:NGeo)
LOGICAL                                 :: isCurvedSide,isRectangular, fullMesh, isBilinear
!===================================================================================================================================

SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_StdOut,'(A)') ' Get Element and Side Type incl. HALO-Sides...'

! elements
ALLOCATE(CurvedElem(1:nTotalElems))
CurvedElem=.FALSE.
nCurvedElems=0
nLinearElems=0

! sides
IF(DoRefMapping)THEN
  ALLOCATE( SideType(nTotalBCSides)        &
          , SideDistance(nTotalBCSides)    &
          , isBCElem(nTotalElems)          &
          , SideIsDone(nTotalSides)        &
          , SideNormVec(1:3,nTotalBCSides) )
ELSE
  ALLOCATE( SideType(nTotalSides)        &
          , SideDistance(nTotalSides)    &
          , isBCElem(nTotalElems)        &
          , SideIsDone(nTotalSides)      &
          , SideNormVec(1:3,nTotalSides) )
END IF
SideIsDone=.FALSE.
SideType=-1

SideDistance=0.
SideNormVec=0.

eps=1e-8

nPlanarRectangular         = 0
nPlanarNonRectangular      = 0
nPlanarCurved              = 0
nBilinear                  = 0
nCurved                    = 0
nBCElems                   = 0
#ifdef MPI
nPlanarRectangularHalo     = 0
nPlanarNonRectangularHalo  = 0
nPlanarCurvedHalo          = 0
nBilinearHalo              = 0
nCurvedHalo                = 0
#endif /*MPI*/
nCurvedElemsHalo           = 0
nLinearElemsHalo           = 0
nCurvedElemsHalo           = 0
nBCElemsHalo               = 0
isBilinear=.FALSE.

NGeo2=(NGeo+1)*(NGeo+1)
NGeo3=NGeo2*(NGeo+1)
nLoop=nTotalElems
IF(.NOT.DoRefMapping) nLoop=PP_nElems
DO iElem=1,nLoop
  ! 1) check if elem is curved
  !   a) map coordinates to compute bilinear mapping
  ! fill dummy
  XCL_NGeo1(1:3,0,0,0) = XCL_NGeo(1:3, 0  , 0  , 0  ,iElem)
  XCL_NGeo1(1:3,1,0,0) = XCL_NGeo(1:3,NGeo, 0  , 0  ,iElem)
  XCL_NGeo1(1:3,0,1,0) = XCL_NGeo(1:3, 0  ,NGeo, 0  ,iElem)
  XCL_NGeo1(1:3,1,1,0) = XCL_NGeo(1:3,NGeo,NGeo, 0  ,iElem)
  XCL_NGeo1(1:3,0,0,1) = XCL_NGeo(1:3, 0  , 0  ,NGeo,iElem)
  XCL_NGeo1(1:3,1,0,1) = XCL_NGeo(1:3,NGeo, 0  ,NGeo,iElem)
  XCL_NGeo1(1:3,0,1,1) = XCL_NGeo(1:3, 0  ,NGeo,NGeo,iElem)
  XCL_NGeo1(1:3,1,1,1) = XCL_NGeo(1:3,NGeo,NGeo,NGeo,iElem)

  CALL ChangeBasis3D(3,1,NGeo,Vdm_CLNGeo1_CLNGeo,XCL_NGeo1,XCL_NGeoNew)
  ! check 3D points
  CALL PointsEqual(NGeo3,XCL_NGeoNew,XCL_NGeo(1:3,0:NGeo,0:NGeo,0:NGeo,iElem),CurvedElem(iElem))

  IF(iElem.LE.PP_nElems)THEN
    IF(CurvedElem(iElem))THEN
      nCurvedElems=nCurvedElems+1
    ELSE
      nLinearElems=nLinearElems+1
    END IF
  ELSE
    IF(Curvedelem(iElem)) THEN
      nCurvedElemsHalo=nCurvedElemsHalo+1
    ELSE
      nLinearElemsHalo=nLinearElemsHalo+1
    END IF
  END IF

  ! 2) check sides
  DO ilocSide=1,6
    SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
    IF (SideID.EQ.-1) CYCLE
    IF(DoRefMapping)THEN
      TrueSideID=PartBCSideList(SideID)
      IF(TrueSideID.EQ.-1)CYCLE
    ELSE
      TrueSideID=SideID
    END IF
    IF (SideIsDone(TrueSideID)) CYCLE
    IF(.NOT.CurvedElem(iElem))THEN
      ! linear element
      IF(BoundingBoxIsEmpty(TrueSideID))THEN
        v1=(-BezierControlPoints3D(:,0,0   ,TrueSideID)+BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
            -BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
        
        v2=(-BezierControlPoints3D(:,0,0   ,TrueSideID)-BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
            +BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
        SideNormVec(:,TrueSideID) = CROSSNORM(v1,v2)
        v1=0.25*(BezierControlPoints3D(:,0,0,TrueSideID)     &
                +BezierControlPoints3D(:,NGeo,0,TrueSideID)  &
                +BezierControlPoints3D(:,0,NGeo,TrueSideID)  &
                +BezierControlPoints3D(:,NGeo,NGeo,TrueSideID))
        SideDistance(TrueSideID)=DOT_PRODUCT(v1,SideNormVec(:,TrueSideID))
        ! check if it is rectangular
        isRectangular=.TRUE.
        v1=BezierControlPoints3D(:,0   ,NGeo,TrueSideID)-BezierControlPoints3D(:,0   ,0   ,TrueSideID)
        v2=BezierControlPoints3D(:,NGeo,0   ,TrueSideID)-BezierControlPoints3D(:,0   ,0   ,TrueSideID)
        v3=BezierControlPoints3D(:,NGeo,NGeo,TrueSideID)-BezierControlPoints3D(:,0   ,NGeo,TrueSideID)
        IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
        IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
        IF(isRectangular)THEN
          v1=BezierControlPoints3D(:,NGeo,NGeo,TrueSideID)-BezierControlPoints3D(:,NGeo,0   ,TrueSideID)
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
        END IF
        IF(isRectangular)THEN
          SideType(TrueSideID)=PLANAR_RECT
          IF(TrueSideID.LE.SideID_Minus_Upper) nPlanarRectangular=nPlanarRectangular+1
#ifdef MPI
          IF(TrueSideID.GT.nSides) nPlanarRectangularHalo=nPlanarRectangularHalo+1
#endif /*MPI*/
        ELSE
          SideType(TrueSideID)=PLANAR_NONRECT
          IF(SideID.LE.SideID_Minus_Upper) nPlanarNonRectangular=nPlanarNonRectangular+1
#ifdef MPI
          IF(SideID.GT.nSides) nPlanarNonRectangularHalo=nPlanarNonRectangularHalo+1
#endif /*MPI*/
        END IF
      ELSE
        SideType(TrueSideID)=BILINEAR
        IF(SideID.LE.SideID_Minus_Upper) nBiLinear=nBiLinear+1
#ifdef MPI
        IF(SideID.GT.nSides) nBilinearHalo=nBilinearHalo+1
#endif /*MPI*/
      END IF
    ELSE
      ! possible curved face
      SELECT CASE(ilocSide)
      CASE(XI_MINUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,0,0:NGeo,0:NGeo,iElem)
        XCL_NGeoSideNew=XCL_NGeoNew(1:3,0,0:NGeo,0:NGeo)
      CASE(XI_PLUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,NGeo,0:NGeo,0:NGeo,iElem)
        XCL_NGeoSideNew=XCL_NGeoNew(1:3,NGeo,0:NGeo,0:NGeo)
      CASE(ETA_MINUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,0:NGeo,0,0:NGeo,iElem)
        XCL_NGeoSideNew=XCL_NGeoNew(1:3,0:NGeo,0,0:NGeo)
      CASE(ETA_PLUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,0:NGeo,NGeo,0:NGeo,iElem)
        XCL_NGeoSideNew=XCL_NGeoNew(1:3,0:NGeo,NGeo,0:NGeo)
      CASE(ZETA_MINUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,0:NGeo,0:NGeo,0,iElem)
        XCL_NGeoSideNew=XCL_NGeoNew(1:3,0:NGeo,0:NGeo,0)
      CASE(ZETA_PLUS)
        XCL_NGeoSideOld=XCL_NGeo   (1:3,0:NGeo,0:NGeo,NGeo,iElem)
        XCL_NGeoSideNew=XCL_NGeoNEw(1:3,0:NGeo,0:NGeo,NGeo)
      END SELECT
      CALL PointsEqual(NGeo2,XCL_NGeoSideNew,XCL_NGeoSideOld,isCurvedSide)
      IF(isCurvedSide)THEn
        IF(BoundingBoxIsEmpty(TrueSideID))THEN
          SideType(TrueSideID)=PLANAR_CURVED
          IF(SideID.LE.SideID_Minus_Upper) nPlanarCurved=nPlanarCurved+1
#ifdef MPI
          IF(SideID.GT.nSides) nPlanarCurvedHalo=nPlanarCurvedHalo+1
#endif /*MPI*/
          v1=(-BezierControlPoints3D(:,0,0   ,TrueSideID)+BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
              -BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
          
          v2=(-BezierControlPoints3D(:,0,0   ,TrueSideID)-BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
              +BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
          SideNormVec(:,TrueSideID) = CROSSNORM(v1,v2)
          v1=0.25*(BezierControlPoints3D(:,0,0,TrueSideID)     &
                  +BezierControlPoints3D(:,NGeo,0,TrueSideID)  &
                  +BezierControlPoints3D(:,0,NGeo,TrueSideID)  &
                  +BezierControlPoints3D(:,NGeo,NGeo,TrueSideID))
          SideDistance(TrueSideID)=DOT_PRODUCT(v1,SideNormVec(:,TrueSideID))
        ELSE
          SideType(TrueSideID)=CURVED
          IF(SideID.LE.SideID_Minus_Upper) nCurved=nCurved+1
#ifdef MPI
          IF(SideID.GT.nSides) nCurvedHalo=nCurvedHalo+1
#endif /*MPI*/
        END IF
      ELSE
        IF(BoundingBoxIsEmpty(TrueSideID))THEN
          v1=(-BezierControlPoints3D(:,0,0   ,TrueSideID)+BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
              -BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
          
          v2=(-BezierControlPoints3D(:,0,0   ,TrueSideID)-BezierControlPoints3D(:,NGeo,0   ,TrueSideID)   &
              +BezierControlPoints3D(:,0,NGeo,TrueSideID)+BezierControlPoints3D(:,NGeo,NGeo,TrueSideID) )
          SideNormVec(:,TrueSideID) = CROSSNORM(v1,v2)
          v1=0.25*(BezierControlPoints3D(:,0,0,TrueSideID)     &
                  +BezierControlPoints3D(:,NGeo,0,TrueSideID)  &
                  +BezierControlPoints3D(:,0,NGeo,TrueSideID)  &
                  +BezierControlPoints3D(:,NGeo,NGeo,TrueSideID))
          SideDistance(TrueSideID)=DOT_PRODUCT(v1,SideNormVec(:,TrueSideID))
          ! check if it is rectangular
          isRectangular=.TRUE.
          v1=BezierControlPoints3D(:,0   ,NGeo,TrueSideID)-BezierControlPoints3D(:,0   ,0   ,TrueSideID)
          v2=BezierControlPoints3D(:,NGeo,0   ,TrueSideID)-BezierControlPoints3D(:,0   ,0   ,TrueSideID)
          v3=BezierControlPoints3D(:,NGeo,NGeo,TrueSideID)-BezierControlPoints3D(:,0   ,NGeo,TrueSideID)
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
          IF(isRectangular)THEN
            v1=BezierControlPoints3D(:,NGeo,NGeo,TrueSideID)-BezierControlPoints3D(:,NGeo,0   ,TrueSideID)
            IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
            IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
          END IF
          IF(isRectangular)THEN
            SideType(TrueSideID)=PLANAR_RECT
            IF(TrueSideID.LE.SideID_Minus_Upper) nPlanarRectangular=nPlanarRectangular+1
#ifdef MPI
            IF(TrueSideID.GT.nSides) nPlanarRectangularHalo=nPlanarRectangularHalo+1
#endif /*MPI*/
          ELSE
            SideType(TrueSideID)=PLANAR_NONRECT
            IF(SideID.LE.SideID_Minus_Upper) nPlanarNonRectangular=nPlanarNonRectangular+1
#ifdef MPI
            IF(SideID.GT.nSides) nPlanarNonRectangularHalo=nPlanarNonRectangularHalo+1
#endif /*MPI*/
          END IF
        ELSE
          SideType(TrueSideID)=BILINEAR
          IF(SideID.LE.SideID_Minus_Upper) nBiLinear=nBiLinear+1
#ifdef MPI
          IF(SideID.GT.nSides) nBilinearHalo=nBilinearHalo+1
#endif /*MPI*/
        END IF
      END IF
    END IF
    SideIsDone(SideID)=.TRUE.
  END DO ! ilocSide=1,6
END DO ! iElem=1,nTotalElems

! build the side type for halo sides
IF (.NOT.DoRefMapping)THEN
  DO iSide=1,nTotalSides
    IF(SideIsDone(iSide)) CYCLE
    IF(iSide.LE.nSides)THEN
      IPWRITE(UNIT_StdOut,*) ' Error in local side lists....'
    END IF
    ! check all four edges for linearity
    isLinear=.TRUE.
    nLoop=NGeo-1
    ! first edge (0,0)->(NGeo,0)
    v1=BezierControlPoints3D(:,NGeo,0   ,iSide)-BezierControlPoints3D(:,0,0,  iSide)   
    DO p=1,nLoop
      v2=BezierControlPoints3D(:,p,0   ,iSide)-BezierControlPoints3D(:,0,0,  iSide)   
      v3=CROSS(v1,v2)
      Length=DOT_PRODUCT(v3,v3)
      IF(.NOT.ALMOSTZERO(Length))THEN
        isLinear=.FALSE.
        EXIT 
      END IF
    END DO
    ! second edge (0,0)->(0,NGeo)
    IF(isLinear)THEN
      v1=BezierControlPoints3D(:,0,NGeo,iSide)-BezierControlPoints3D(:,0,0,  iSide)   
      DO p=1,nLoop
        v2=BezierControlPoints3D(:,0,p,iSide)-BezierControlPoints3D(:,0,0,  iSide)   
        v3=CROSS(v1,v2)
        Length=DOT_PRODUCT(v3,v3)
        IF(.NOT.ALMOSTZERO(Length))THEN
          isLinear=.FALSE.
          EXIT 
        END IF
      END DO
    END IF
    ! third edge (N,N)->(0,NGeo)
    IF(isLinear)THEN
      v1=BezierControlPoints3D(:,0,NGeo,iSide)-BezierControlPoints3D(:,NGeo,NGeo,iSide)   
      DO p=1,nLoop
        v2=BezierControlPoints3D(:,0,p,iSide)-BezierControlPoints3D(:,NGeo,NGeo,iSide)   
        v3=CROSS(v1,v2)
        Length=DOT_PRODUCT(v3,v3)
        IF(.NOT.ALMOSTZERO(Length))THEN
          isLinear=.FALSE.
          EXIT 
        END IF
      END DO
    END IF
    ! forth edge (N,N)->(NGeo,0)
    IF(isLinear)THEN
      v1=BezierControlPoints3D(:,NGeo,0,iSide)-BezierControlPoints3D(:,NGeo,NGeo,iSide)   
      DO p=1,nLoop
        v2=BezierControlPoints3D(:,p,0,iSide)-BezierControlPoints3D(:,NGeo,NGeo,iSide)   
        v3=CROSS(v1,v2)
        Length=DOT_PRODUCT(v3,v3)
        IF(.NOT.ALMOSTZERO(Length))THEN
          isLinear=.FALSE.
          EXIT 
        END IF
      END DO
    END IF
    IF(isLinear)THEN
      IF(BoundingBoxIsEmpty(iSide))THEN
        v1=(-BezierControlPoints3D(:,0,0   ,iSide)+BezierControlPoints3D(:,NGeo,0   ,iSide)   &
            -BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
        
        v2=(-BezierControlPoints3D(:,0,0   ,iSide)-BezierControlPoints3D(:,NGeo,0   ,iSide)   &
            +BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
        SideNormVec(:,iSide) = CROSSNORM(v1,v2)
        v1=0.25*(BezierControlPoints3D(:,0,0,iSide)     &
                +BezierControlPoints3D(:,NGeo,0,iSide)  &
                +BezierControlPoints3D(:,0,NGeo,iSide)  &
                +BezierControlPoints3D(:,NGeo,NGeo,iSide))
        SideDistance(iSide)=DOT_PRODUCT(v1,SideNormVec(:,iSide))
        ! check if it is rectangular
        isRectangular=.TRUE.
        v1=BezierControlPoints3D(:,0   ,NGeo,iSide)-BezierControlPoints3D(:,0   ,0   ,iSide)
        v2=BezierControlPoints3D(:,NGeo,0   ,iSide)-BezierControlPoints3D(:,0   ,0   ,iSide)
        v3=BezierControlPoints3D(:,NGeo,NGeo,iSide)-BezierControlPoints3D(:,0   ,NGeo,iSide)
        IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
        IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
        IF(isRectangular)THEN
          v1=BezierControlPoints3D(:,NGeo,NGeo,iSide)-BezierControlPoints3D(:,NGeo,0   ,iSide)
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v2))) isRectangular=.FALSE.
          IF(.NOT.ALMOSTZERO(DOT_PRODUCT(v1,v3))) isRectangular=.FALSE.
        END IF
        IF(isRectangular)THEN
          SideType(iSide)=PLANAR_RECT
          IF(iSide.LE.SideID_Minus_Upper) nPlanarRectangular=nPlanarRectangular+1
#ifdef MPI
          IF(iSide.GT.nSides) nPlanarRectangularHalo=nPlanarRectangularHalo+1
#endif /*MPI*/
        ELSE
          SideType(iSide)=PLANAR_NONRECT
          IF(SideID.LE.SideID_Minus_Upper) nPlanarNonRectangular=nPlanarNonRectangular+1
#ifdef MPI
          IF(SideID.GT.nSides) nPlanarNonRectangularHalo=nPlanarNonRectangularHalo+1
#endif /*MPI*/
        END IF
      ELSE
        ! check if bilinear 
        ! isBiLinear=.TRUE.
        ! IF(NGeo.GT.1)THEN
        !   ! check a line in xi and in eta for linearity
        !   nLoop=NGeo-1
        !   ! first lines (0,1:NGeo-1)->(NGeo,1:NGeo-1)
        !   DO p=1,nLoop
        !     IF(isBilinear)THEN
        !        v1=BezierControlPoints3D(:,NGeo,p   ,iSide)-BezierControlPoints3D(:,0,p,  iSide)   
        !        DO q=1,nLoop
        !          v2=BezierControlPoints3D(:,q,p   ,iSide)-BezierControlPoints3D(:,0,p,  iSide)   
        !          v3=CROSS(v1,v2)
        !          Length=DOT_PRODUCT(v3,v3)
        !          IF(.NOT.ALMOSTZERO(Length))THEN
        !            isBiLinear=.FALSE.
        !            EXIT 
        !          END IF
        !        END DO ! q=1,nLoop
        !     END IF
        !   END DO ! p=1,nLOOP
        !   ! second lines (1:NGeo-1,0)->(1:NGeo-1,nGeo)
        !   DO p=1,nLoop
        !     IF(isBilinear)THEN
        !        v1=BezierControlPoints3D(:,p,NGeo  ,iSide)-BezierControlPoints3D(:,p,0,  iSide)   
        !        DO q=1,nLoop
        !          v2=BezierControlPoints3D(:,p,q   ,iSide)-BezierControlPoints3D(:,p,0,  iSide)   
        !          v3=CROSS(v1,v2)
        !          Length=DOT_PRODUCT(v3,v3)
        !          IF(.NOT.ALMOSTZERO(Length))THEN
        !            isBiLinear=.FALSE.
        !            EXIT 
        !          END IF
        !        END DO ! q=1,nLoop
        !     END IF
        !   END DO ! p=1,nLOOP
        ! END IF
        IF(isBiLinear)THEN
          SideType(iSide)=BILINEAR
          IF(SideID.LE.SideID_Minus_Upper) nBiLinear=nBiLinear+1
#ifdef MPI
          IF(SideID.GT.nSides) nBilinearHalo=nBilinearHalo+1
#endif /*MPI*/
        ELSE ! not bilinear
          IF(BoundingBoxIsEmpty(iSide))THEN
            SideType(TrueSideID)=PLANAR_CURVED
            IF(SideID.LE.SideID_Minus_Upper) nPlanarCurved=nPlanarCurved+1
#ifdef MPI
            IF(SideID.GT.nSides) nPlanarCurvedHalo=nPlanarCurvedHalo+1
#endif /*MPI*/
            v1=(-BezierControlPoints3D(:,0,0   ,iSide)+BezierControlPoints3D(:,NGeo,0   ,iSide)   &
                -BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
            
            v2=(-BezierControlPoints3D(:,0,0   ,iSide)-BezierControlPoints3D(:,NGeo,0   ,iSide)   &
                +BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
            SideNormVec(:,iSide) = CROSSNORM(v1,v2)
            v1=0.25*(BezierControlPoints3D(:,0,0,iSide)     &
                    +BezierControlPoints3D(:,NGeo,0,iSide)  &
                    +BezierControlPoints3D(:,0,NGeo,iSide)  &
                    +BezierControlPoints3D(:,NGeo,NGeo,iSide))
            SideDistance(iSide)=DOT_PRODUCT(v1,SideNormVec(:,iSide))
          ELSE
            SideType(TrueSideID)=CURVED
            IF(SideID.LE.SideID_Minus_Upper) nCurved=nCurved+1
#ifdef MPI
            IF(SideID.GT.nSides) nCurvedHalo=nCurvedHalo+1
#endif /*MPI*/
          END IF
        END IF
      END IF ! bounding bos is empty
    ELSE  ! non-linear edges
      IF(BoundingBoxIsEmpty(iSide))THEN
        SideType(iSide)=PLANAR_CURVED
        IF(SideID.LE.SideID_Minus_Upper) nPlanarCurved=nPlanarCurved+1
#ifdef MPI
        IF(SideID.GT.nSides) nPlanarCurvedHalo=nPlanarCurvedHalo+1
#endif /*MPI*/
        v1=(-BezierControlPoints3D(:,0,0   ,iSide)+BezierControlPoints3D(:,NGeo,0   ,iSide)   &
            -BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
        
        v2=(-BezierControlPoints3D(:,0,0   ,iSide)-BezierControlPoints3D(:,NGeo,0   ,iSide)   &
            +BezierControlPoints3D(:,0,NGeo,iSide)+BezierControlPoints3D(:,NGeo,NGeo,iSide) )
        SideNormVec(:,iSide) = CROSSNORM(v1,v2)
        v1=0.25*(BezierControlPoints3D(:,0,0,iSide)     &
                +BezierControlPoints3D(:,NGeo,0,iSide)  &
                +BezierControlPoints3D(:,0,NGeo,iSide)  &
                +BezierControlPoints3D(:,NGeo,NGeo,iSide))
        SideDistance(iSide)=DOT_PRODUCT(v1,SideNormVec(:,iSide))
      ELSE
        SideType(iSide)=CURVED
        IF(SideID.LE.SideID_Minus_Upper) nCurved=nCurved+1
#ifdef MPI
        IF(SideID.GT.nSides) nCurvedHalo=nCurvedHalo+1
#endif /*MPI*/
      END IF
    END IF
  END DO ! iSide=1,nTotalSides
END IF

IF(DoRefMapping)THEN
  ! mark elements as bc element
  IsBCElem=.FALSE.
  nTotalBCElems=0
  DO iElem=1,nTotalElems
    DO ilocSide=1,6
      SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
      IF (SideID.LE.0) CYCLE
      IF((SideID.LE.nBCSides).OR.(SideID.GT.nSides))THEN
        IF(.NOT.isBCElem(iElem))THEN
          IsBCElem(iElem)=.TRUE.
          nTotalBCElems=nTotalBCElems+1
          IF(SideID.LE.nBCSides)THEN
            nBCElems=nBCElems+1
          ELSE
            nBCElemsHalo=nBCElemsHalo+1
          END IF
        END IF ! count only single
      END IF
    END DO ! ilocSide
  END DO ! iElem
  ! get distance of halo_eps
  V1(1) = GEO%xmaxglob-GEO%xminglob
  V1(2) = GEO%ymaxglob-GEO%yminglob
  V1(3) = GEO%zmaxglob-GEO%zminglob
  Distance=DOT_PRODUCT(V1,V1)
  fullMesh=.FALSE.
  IF(Distance.LE.halo_eps2) fullMesh=.TRUE.  ! build list with elements in halo-eps vicinity around bc-elements
  ALLOCATE( BCElem(1:nTotalElems) )
  ALLOCATE( SideIndex(1:nTotalSides) )
  ! number of element local BC-Sides
  DO iElem=1,nTotalElems
    BCElem(iElem)%nInnerSides=0
#if (PP_TimeDiscMethod==1)||(PP_TimeDiscMethod==2)||(PP_TimeDiscMethod==6)||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=506)
    IF(.NOT.isBCElem(iElem)) CYCLE
#endif
    DO ilocSide=1,6
      SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
      IF(SideID.EQ.-1) CYCLE
      IF(PartBCSideList(SideID).EQ.-1) CYCLE
      BCElem(iElem)%nInnerSides = BCElem(iElem)%nInnerSides+1
      !END IF
    END DO ! ilocSide
    BCElem(iElem)%lastSide=BCElem(iElem)%nInnerSides
    ! loop over all sides
    SideIndex=0
    DO iSide=1,nTotalSides
      ! only bc sides
      BCSideID  =PartBCSideList(iSide)
      IF(BCSideID.EQ.-1) CYCLE
      ! ignore sides of the same element
      IF(PartSideToElem(S2E_ELEM_ID,iSide).EQ.iElem) CYCLE
      ! next, get all sides in halo-eps vicinity
      DO ilocSide=1,6
        SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
        IF(SideID.EQ.-1) CYCLE
#if (PP_TimeDiscMethod==1)||(PP_TimeDiscMethod==2)||(PP_TimeDiscMethod==6)||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=506)
        BCSideID2 =PartBCSideList(SideID)
        IF(BCSideID2.EQ.-1) CYCLE
        leave=.FALSE.
        ! all points of bc side
        DO q=0,NGeo
          DO p=0,NGeo
            NodeX(:) = BezierControlPoints3D(:,p,q,BCSideID)
            ! all nodes of current side
            DO s=0,NGeo
              DO r=0,NGeo
                IF(SQRT(DOT_Product(BezierControlPoints3D(:,r,s,BCSideID2)-NodeX &
                                   ,BezierControlPoints3D(:,r,s,BCSideID2)-NodeX )).LE.halo_eps)THEN
                  IF(SideIndex(iSide).EQ.0)THEN
                    BCElem(iElem)%lastSide=BCElem(iElem)%lastSide+1
                    SideIndex(iSide)=BCElem(iElem)%lastSide
                    leave=.TRUE.
                    EXIT
                  END IF
                END IF
              END DO ! r
              IF(leave) EXIT
            END DO ! s
            IF(leave) EXIT
          END DO ! p
          IF(leave) EXIT
        END DO ! q
#else /* no LSERK */
        ! simplified version
        IF(fullMesh)THEN
          IF(SideIndex(iSide).EQ.0)THEN
            BCElem(iElem)%lastSide=BCElem(iElem)%lastSide+1
            SideIndex(iSide)=BCElem(iElem)%lastSide
          END IF
        ELSE
          leave=.FALSE.
          !DO q=0,NGeo
          !  DO p=0,NGeo
          !    V1=BezierControlPoints3D(1:3,p,q,BCSideID)-ElemBaryNGeo(1:3,iElem)
          !    Distance=DOT_PRODUCT(V1,V1)-ElemRadius2NGeo(iElem)
          !    IF(Distance.LE.halo_eps2)THEN
          !      IF(SideIndex(iSide).EQ.0)THEN
          !        BCElem(iElem)%lastSide=BCElem(iElem)%lastSide+1
          !        SideIndex(iSide)=BCElem(iElem)%lastSide
          !        leave=.TRUE.
          !        EXIT
          !      END IF
          !    END IF
          !  END DO ! p=0,NGeo
          !  IF(leave) EXIT
          !END DO !  q=0,NGeo
          SELECT CASE(ilocSide)
          CASE(XI_MINUS)
            xNodes=XCL_NGeo(1:3,0,0:NGeo,0:NGeo,iElem)
          CASE(XI_PLUS)
            xNodes=XCL_NGeo(1:3,NGeo,0:NGeo,0:NGeo,iElem)
          CASE(ETA_MINUS)
            xNodes=XCL_NGeo(1:3,0:NGeo,0,0:NGeo,iElem)
          CASE(ETA_PLUS)
            xNodes=XCL_NGeo(1:3,0:NGeo,NGeo,0:NGeo,iElem)
          CASE(ZETA_MINUS)
            xNodes=XCL_NGeo(1:3,0:NGeo,0:NGeo,0,iElem)
          CASE(ZETA_PLUS)
            xNodes=XCL_NGeo(1:3,0:NGeo,0:NGeo,NGeo,iElem)
          END SELECT
          leave=.FALSE.
          ! all points of bc side
          DO q=0,NGeo
            DO p=0,NGeo
              NodeX(:) = BezierControlPoints3D(:,p,q,BCSideID)
              !all nodes of current side
              DO s=0,NGeo
                DO r=0,NGeo
                  IF(SQRT(DOT_Product(xNodes(:,r,s)-NodeX &
                                     ,xNodes(:,r,s)-NodeX )).LE.halo_eps)THEN
                    IF(SideIndex(iSide).EQ.0)THEN
                      BCElem(iElem)%lastSide=BCElem(iElem)%lastSide+1
                      SideIndex(iSide)=BCElem(iElem)%lastSide
                      leave=.TRUE.
                      EXIT
                    END IF
                  END IF
                END DO ! r
                IF(leave) EXIT
              END DO ! s
              IF(leave) EXIT
            END DO ! p
            IF(leave) EXIT
          END DO ! q
        END IF
#endif
        IF(leave) EXIT
      END DO ! ilocSide
    END DO ! iSide
    ! finally, allocate the bc side list
    IF(BCElem(iElem)%lastSide.EQ.0) CYCLE
    ! set true, only required for elements without an own bc side
    IF(.NOT.isBCElem(iElem))THEN
      IF(iElem.LE.PP_nElems) THEN
        nBCElems=nBCElems+1
      ELSE
        nBCElemsHalo=nBCElemsHalo+1
      END IF
    END IF
    isBCElem(iElem)=.TRUE.
    ! allocate complete side list
    ALLOCATE( BCElem(iElem)%BCSideID(BCElem(iElem)%lastSide) )
    ! 1) inner sides
    nSideCount=0
    IF(BCElem(iElem)%nInnerSides.GT.0)THEN
      DO ilocSide=1,6
        SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
        IF(SideID.EQ.-1) CYCLE
        BCSideID=PartBCSideList(SideID)
        IF(BCSideID.EQ.-1) CYCLE
       ! IF((SideID.LE.nBCSides).OR.(SideID.GT.nSides))THEN
        nSideCount=nSideCount+1
        !BCElem(iElem)%BCSideID(nSideCount)= BCSideID
        BCElem(iElem)%BCSideID(nSideCount)= SideID
        !END IF
      END DO ! ilocSide
    END IF ! nInnerSides.GT.0
    ! 2) outer sides
    DO iSide=1,nTotalSides
      IF(SideIndex(iSide).GT.0)THEN
        nSideCount=nSideCount+1
        BCSideID=PartBCSideList(iSide)
        !BCElem(iElem)%BCSideID(nSideCount)=BCSideID
        BCElem(iElem)%BCSideID(nSideCount)=iSide
      END IF
    END DO  ! iSide
    SideIndex=0
  END DO ! iElem
ELSE
  ! tracing
  ! mark only elements with bc-side
  IsBCElem=.FALSE.
  nTotalBCElems=0
  DO iElem=1,nTotalElems
    DO ilocSide=1,6
      SideID=PartElemToSide(E2S_SIDE_ID,ilocSide,iElem)
      IF (SideID.LE.0) CYCLE
      IF(SideID.LE.nBCSides)THEN ! non-halo elements
        IF(.NOT.isBCElem(iElem))THEN
          IsBCElem(iElem)=.TRUE.
          nTotalBCElems=nTotalBCElems+1
          IF(SideID.LE.nBCSides)THEN
            nBCElems=nBCElems+1
          ELSE
            nBCElemsHalo=nBCElemsHalo+1
          END IF
        END IF ! count only single
      END IF
#ifdef MPI
      IF(SideID.GT.nSides)THEN ! halo elements
        IF(BC(SideID).NE.0)THEN
          IF(.NOT.isBCElem(iElem))THEN
            IsBCElem(iElem)=.TRUE.
            nTotalBCElems=nTotalBCElems+1
            IF(SideID.LE.nBCSides)THEN
              nBCElems=nBCElems+1
            ELSE
              nBCElemsHalo=nBCElemsHalo+1
            END IF
          END IF ! count only single
        END IF
      END IF ! SideID.GT.nSides
#endif
    END DO ! ilocSide
  END DO ! iElem
END IF

#ifdef MPI
IF(MPIRoot) THEN
  CALL MPI_REDUCE(nPlanarRectangular   ,nPlanarRectangularTot   ,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nPlanarNonRectangular,nPlanarNonRectangularTot,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nBilinear            ,nBilinearTot            ,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nPlanarCurved        ,nPlanarCurvedTot        ,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nCurved              ,nCurvedTot              ,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nCurvedElems,nCurvedElemsTot,1,MPI_INTEGER,MPI_SUM,0,PartMPI%COMM,IERROR)
  IF(DoRefMapping) CALL MPI_REDUCE(nBCElems,nBCElemsTot ,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
ELSE ! no Root
  CALL MPI_REDUCE(nPlanarRectangular     ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nPlanarNonRectangular  ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nBilinear              ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nPlanarCurved          ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nCurved                ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
  CALL MPI_REDUCE(nCurvedElems           ,nDummy,1,MPI_INTEGER,MPI_SUM,0,PartMPI%COMM,IERROR)
  IF(DoRefMapping) CALL MPI_REDUCE(nBCElems  ,nDummy,1,MPI_INTEGER,MPI_SUM,0,MPI_COMM_WORLD,IERROR)
END IF
#else
nPlanarRectangularTot   =nPlanarRectangular
nPlanarNonRectangularTot=nPlanarNonRectangular
nBilinearTot            =nBilinear
nPlanarCurvedTot        =nPlanarCurved
nCurvedTot              =nCurved
nCurvedElemsTot         =nCurvedElems
IF(DorefMapping) nBCElemstot=nBCElems
#endif /*MPI*/

SWRITE(UNIT_StdOut,'(A,I8)') ' Number of planar-rectangular     faces: ', nPlanarRectangulartot
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of planar-non-rectangular faces: ', nPlanarNonRectangulartot
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of bi-linear              faces: ', nBilineartot
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of planar-curved          faces: ', nPlanarCurvedtot
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of curved                 faces: ', nCurvedtot
! and add number of curved elems
IF(DoRefMapping)THEN
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of BC-adjoined            elems: ', nBCElemstot
END IF
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of (bi-)linear            elems: ', nGlobalElems-nCurvedElemsTot
SWRITE(UNIT_StdOut,'(A,I8)') ' Number of curved                 elems: ', nCurvedElemsTot
SWRITE(UNIT_StdOut,'(132("-"))')

#ifdef MPI
CALL WriteParticlePartitionInformation(nPlanarRectangular+nPlanarNonRectangular,nBilinear,nCurved+nPlanarCurved,                    &
                                       nPlanarRectangularHalo+nPlanarNonRectangularHalo,nBilinearHalo,nCurvedHalo+nPlanarCurvedHalo &
                                      ,nBCElems,nLinearElems,nCurvedElems,nBCElemsHalo,nLinearElemsHalo,nCurvedElemsHalo)
#endif

! finally, build epsonecell per element
IF(DoRefMapping)THEN
  ALLOCATE(epsOneCell(1:nTotalElems))
ELSE
  ALLOCATE(epsOneCell(1:PP_nElems))
END IF

nLoop=nTotalElems
IF(.NOT.DoRefMapping) nLoop=PP_nElems
maxScaleJ=0.
DO iElem=1,PP_nElems
  scaleJ=MAXVAL(sJ(:,:,:,iElem))/MINVAL(sJ(:,:,:,iElem))
  epsOneCell(iElem)=1.0+SQRT(3.0*scaleJ*RefMappingEps)
  maxScaleJ=MAX(scaleJ,maxScaleJ)
END DO ! iElem=1,nLoop
DO iElem=PP_nElems+1,nLoop
  epsOneCell(iElem)=1.0+SQRT(maxScaleJ*RefMappingEps)
END DO ! iElem=1,nLoop

END SUBROUTINE GetElemAndSideType

SUBROUTINE BGMIndexOfElement(ElemID,ElemToBGM) 
!===================================================================================================================================
! computes the element indices of an given element in the BGM-mesh
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_ChangeBasis,                        ONLY:ChangeBasis2D
USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D,sVdm_Bezier
USE MOD_Particle_Surfaces_Vars,             ONLY:sVdm_Bezier
USE MOD_Mesh_Vars,                          ONLY:XCL_NGeo
USE MOD_Mesh_Vars,                          ONLY:nSides,NGeo
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems
USE MOD_Particle_Tracking_Vars,             ONLY:DoRefMapping
USE MOD_Particle_Mesh_Vars,                 ONLY:PartElemToSide
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
INTEGER,INTENT(IN)        :: ElemID
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
INTEGER,INTENT(OUT)       :: ElemToBGM(1:6)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: ilocSide, SideID
REAL                      :: xmin,xmax,ymin,ymax,zmin,zmax
REAL                      :: BezierControlPoints3D_tmp(1:3,0:NGeo,0:NGeo)
!===================================================================================================================================

xmin = HUGE(1.0)
xmax =-HUGE(1.0)
ymin = HUGE(1.0)
ymax =-HUGE(1.0)
zmin = HUGE(1.0)
zmax =-HUGE(1.0)

! get min,max of BezierControlPoints of Element
DO iLocSide = 1,6
  SideID = PartElemToSide(E2S_SIDE_ID, ilocSide, ElemID)
  IF(DoRefMapping)THEN
    IF(SideID.GT.0)THEN
      IF(PartElemToSide(E2S_FLIP,ilocSide,ElemID).EQ.0)THEN
        BezierControlPoints3d_tmp=BezierControlPoints3D(:,:,:,SideID)
      ELSE
        SELECT CASE(ilocSide)
        CASE(XI_MINUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,0,:,:,ElemID),BezierControlPoints3D_tmp)
        CASE(XI_PLUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,NGeo,:,:,ElemID),BezierControlPoints3D_tmp)
        CASE(ETA_MINUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,0,:,ElemID),BezierControlPoints3D_tmp)
        CASE(ETA_PLUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,NGeo,:,ElemID),BezierControlPoints3D_tmp)
        CASE(ZETA_MINUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,:,0,ElemID),BezierControlPoints3D_tmp)
        CASE(ZETA_PLUS)
          CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,:,NGeo,ElemID),BezierControlPoints3D_tmp)
        END SELECT
      END IF
    ELSE
      SELECT CASE(ilocSide)
      CASE(XI_MINUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,0,:,:,ElemID),BezierControlPoints3D_tmp)
      CASE(XI_PLUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,NGeo,:,:,ElemID),BezierControlPoints3D_tmp)
      CASE(ETA_MINUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,0,:,ElemID),BezierControlPoints3D_tmp)
      CASE(ETA_PLUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,NGeo,:,ElemID),BezierControlPoints3D_tmp)
      CASE(ZETA_MINUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,:,0,ElemID),BezierControlPoints3D_tmp)
      CASE(ZETA_PLUS)
        CALL ChangeBasis2D(3,NGeo,NGeo,sVdm_Bezier,XCL_NGeo(1:3,:,:,NGeo,ElemID),BezierControlPoints3D_tmp)
      END SELECT
    END IF
  ELSE ! pure tracing
    BezierControlPoints3d_tmp=BezierControlPoints3D(:,:,:,SideID)
  END IF
  xmin=MIN(xmin,MINVAL(BezierControlPoints3D_tmp(1,:,:)))
  xmax=MAX(xmax,MAXVAL(BezierControlPoints3D_tmp(1,:,:)))
  ymin=MIN(ymin,MINVAL(BezierControlPoints3D_tmp(2,:,:)))
  ymax=MAX(ymax,MAXVAL(BezierControlPoints3D_tmp(2,:,:)))
  zmin=MIN(zmin,MINVAL(BezierControlPoints3D_tmp(3,:,:)))
  zmax=MAX(zmax,MAXVAL(BezierControlPoints3D_tmp(3,:,:)))
END DO ! ilocSide

ElemToBGM(1) = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
ElemToBGM(2) = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
ElemToBGM(3) = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
ElemToBGM(4) = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
ElemToBGM(5) = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
ElemToBGM(6) = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))


END SUBROUTINE BGMIndexOfElement


SUBROUTINE GetFIBGMMinMax() 
!===================================================================================================================================
! computes the minimum and maximum value of the FIBGM mesh
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO
USE MOD_Particle_Mesh_Vars,                 ONLY:GEO,nTotalElems,nTotalSides
USE MOD_Particle_Surfaces_Vars,             ONLY:BezierControlPoints3D
#ifdef MPI
USE MOD_Particle_MPI_Vars,                  ONLY:PartMPI
#endif /*MPI*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER         :: iSide
REAL            :: xmin, xmax, ymin, ymax, zmin, zmax
!===================================================================================================================================

!#ifdef MPI
!   !--- If this MPI process does not contain particles, step out
!   IF (PMPIVAR%GROUP.EQ.MPI_GROUP_EMPTY) RETURN
!#endif
!--- calc min and max coordinates for mesh
xmin = HUGE(1.0)
xmax =-HUGE(1.0)
ymin = HUGE(1.0)
ymax =-HUGE(1.0)
zmin = HUGE(1.0)
zmax =-HUGE(1.0)

! serch for min,max of BezierControlPoints, e.g. the convec hull of the domain
! more accurate, XCL_NGeo
!DO iElem=1,nTotalElems
!  xmin=MIN(xmin,MINVAL(XCL_NGeo(1,:,:,:,iElem)))
!  xmax=MAX(xmax,MAXVAL(XCL_NGeo(1,:,:,:,iElem)))
!  ymin=MIN(ymin,MINVAL(XCL_NGeo(2,:,:,:,iElem)))
!  ymax=MAX(ymax,MAXVAL(XCL_NGeo(2,:,:,:,iElem)))
!  zmin=MIN(zmin,MINVAL(XCL_NGeo(3,:,:,:,iElem)))
!  zmax=MAX(zmax,MAXVAL(XCL_NGeo(3,:,:,:,iElem)))
!END DO ! iElem

! bounding box!!
DO iSide=1,nTotalSides
  xmin=MIN(xmin,MINVAL(BezierControlPoints3D(1,:,:,iSide)))
  xmax=MAX(xmax,MAXVAL(BezierControlPoints3D(1,:,:,iSide)))
  ymin=MIN(ymin,MINVAL(BezierControlPoints3D(2,:,:,iSide)))
  ymax=MAX(ymax,MAXVAL(BezierControlPoints3D(2,:,:,iSide)))
  zmin=MIN(zmin,MINVAL(BezierControlPoints3D(3,:,:,iSide)))
  zmax=MAX(zmax,MAXVAL(BezierControlPoints3D(3,:,:,iSide)))
END DO ! iSide

GEO%xmin=xmin
GEO%xmax=xmax
GEO%ymin=ymin
GEO%ymax=ymax
GEO%zmin=zmin
GEO%zmax=zmax

#ifdef MPI
! get global min, max
  CALL MPI_ALLREDUCE(GEO%xmin, GEO%xminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%ymin, GEO%yminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%zmin, GEO%zminglob, 1, MPI_DOUBLE_PRECISION, MPI_MIN, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%xmax, GEO%xmaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%ymax, GEO%ymaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
  CALL MPI_ALLREDUCE(GEO%zmax, GEO%zmaxglob, 1, MPI_DOUBLE_PRECISION, MPI_MAX, PartMPI%COMM, IERROR)
#else
  GEO%xminglob=GEO%xmin
  GEO%yminglob=GEO%ymin
  GEO%zminglob=GEO%zmin
  GEO%xmaxglob=GEO%xmax
  GEO%ymaxglob=GEO%ymax
  GEO%zmaxglob=GEO%zmax
#endif   


END SUBROUTINE GetFIBGMMinMax

END MODULE MOD_Particle_Mesh
