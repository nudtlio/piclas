!==================================================================================================================================
! Copyright (c) 2010 - 2018 Prof. Claus-Dieter Munz and Prof. Stefanos Fasoulas
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


MODULE MOD_Dielectric
!===================================================================================================================================
! Dielectric material handling in Maxwell's (maxwell dielectric) or Poisson's (HDG dielectric) equations
!===================================================================================================================================
! MODULES
USE MOD_io_HDF5
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE InitDielectric
  MODULE PROCEDURE InitDielectric
END INTERFACE
INTERFACE FinalizeDielectric
  MODULE PROCEDURE FinalizeDielectric
END INTERFACE

PUBLIC::InitDielectric,FinalizeDielectric
!===================================================================================================================================
PUBLIC::DefineParametersDielectric
CONTAINS

!==================================================================================================================================
!> Define parameters for surfaces (particle-sides)
!==================================================================================================================================
SUBROUTINE DefineParametersDielectric()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: prms
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("Dielectric Region")

CALL prms%CreateLogicalOption(  'DoDielectric'                 , 'Use dielectric regions with EpsR and MuR' , '.FALSE.')
CALL prms%CreateLogicalOption(  'DielectricFluxNonConserving'  , 'Use non-conservative fluxes at dielectric interfaces between a'&
                                                               //'dielectric region and vacuum' , '.FALSE.')
CALL prms%CreateRealOption(     'DielectricEpsR'               , 'Relative permittivity' , '1.')
CALL prms%CreateRealOption(     'DielectricMuR'                , 'Relative permeability' , '1.')
CALL prms%CreateLogicalOption(  'DielectricNoParticles'        , 'Do not insert/emit particles into dielectric regions' , '.TRUE.')
CALL prms%CreateStringOption(   'DielectricTestCase'           , 'Specific test cases: "FishEyeLens", "FH_lens", "Circle"' , 'default')
CALL prms%CreateRealOption(     'DielectricRmax'               , 'Radius parameter for functions' , '1.')
CALL prms%CreateLogicalOption(  'DielectricCheckRadius'        , 'Use additional parameter "DielectricRadiusValue" for checking'&
                                                               //' if a DOF is within a dielectric region' ,'.FALSE.')
CALL prms%CreateRealOption(     'DielectricRadiusValue'        , 'Additional parameter radius for checking if a DOF is'&
                                                               //' within a dielectric region' , '-1.')
CALL prms%CreateIntOption(     'DielectricAxis'               , 'Additional parameter spatial direction (cylinder) if a DOF is'&
                                                               //' within a dielectric region (Default = z-axis)' , '3')
CALL prms%CreateRealOption(     'DielectricRadiusValueB'        , '2nd radius for cutting out circular areas'&
                                                               //' within a dielectric region' , '-1.')
CALL prms%CreateRealArrayOption('xyzPhysicalMinMaxDielectric'  , '[xmin, xmax, ymin, ymax, zmin, zmax] vector for defining a '&
    //'dielectric region by giving the bounding box coordinates of the PHYSICAL region', '0.0 , 0.0 , 0.0 , 0.0 , 0.0 , 0.0')
CALL prms%CreateRealArrayOption('xyzDielectricMinMax'          , '[xmin, xmax, ymin, ymax, zmin, zmax] vector for defining a '&
    //'dielectric region by giving the bounding box coordinates of the DIELECTRIC region', '0.0 , 0.0 , 0.0 , 0.0 , 0.0 , 0.0')
CALL prms%CreateRealOption(     'Dielectric_E_0'               , 'Electric field strength parameter for functions' , '1.')

END SUBROUTINE DefineParametersDielectric

SUBROUTINE InitDielectric()
!===================================================================================================================================
!  Initialize perfectly matched layer
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_ReadInTools
USE MOD_Dielectric_Vars
USE MOD_HDF5_Output_Tools ,ONLY: WriteDielectricGlobalToHDF5
USE MOD_Equation_Vars     ,ONLY: c
USE MOD_Interfaces        ,ONLY: FindInterfacesInRegion,FindElementInRegion,CountAndCreateMappings,DisplayRanges,SelectMinMaxRegion
USE MOD_Mesh              ,ONLY: GetMeshMinMaxBoundaries
#if ! (USE_HDG)
USE MOD_Equation_Vars     ,ONLY: c_corr
#endif /*if not USE_HDG*/
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT Dielectric...'
!===================================================================================================================================
! Readin
!===================================================================================================================================
DoDielectric                     = GETLOGICAL('DoDielectric','.FALSE.')
IF(.NOT.DoDielectric) THEN
  SWRITE(UNIT_stdOut,'(A)') ' Dielectric region deactivated. '
  nDielectricElems=0
  RETURN
END IF
DielectricNoParticles            = GETLOGICAL('DielectricNoParticles')
DielectricFluxNonConserving      = GETLOGICAL('DielectricFluxNonConserving')
DielectricEpsR                   = GETREAL('DielectricEpsR')
DielectricMuR                    = GETREAL('DielectricMuR')
DielectricTestCase               = GETSTR('DielectricTestCase')
DielectricRmax                   = GETREAL('DielectricRmax')
IF((DielectricEpsR.LE.0.0).OR.(DielectricMuR.LE.0.0))THEN
  CALL abort(&
  __STAMP__&
  ,'Dielectric: MuR or EpsR cannot be negative or zero.')
END IF
DielectricEpsR_inv               = 1./(DielectricEpsR)                   ! 1./EpsR
!DielectricConstant_inv           = 1./(DielectricEpsR*DielectricMuR)    ! 1./(EpsR*MuR)
DielectricConstant_RootInv       = 1./sqrt(DielectricEpsR*DielectricMuR) ! 1./sqrt(EpsR*MuR)
#if !(USE_HDG)
eta_c_dielectric                 = (c_corr-DielectricConstant_RootInv)*c ! ( chi - 1./sqrt(EpsR*MuR) ) * c
#endif /*if USE_HDG*/
c_dielectric                     = c*DielectricConstant_RootInv          ! c/sqrt(EpsR*MuR)
c2_dielectric                    = c*c/(DielectricEpsR*DielectricMuR)    ! c**2/(EpsR*MuR)
DielectricCheckRadius            = GETLOGICAL('DielectricCheckRadius')
DielectricRadiusValue            = GETREAL('DielectricRadiusValue')
DielectricCircleAxis             = GETINT('DielectricAxis')
IF(DielectricRadiusValue.LE.0.0) DielectricCheckRadius=.FALSE.
DielectricRadiusValueB           = GETREAL('DielectricRadiusValueB')
! determine Dielectric elements
xyzPhysicalMinMaxDielectric(1:6) = GETREALARRAY('xyzPhysicalMinMaxDielectric',6)
xyzDielectricMinMax(1:6)         = GETREALARRAY('xyzDielectricMinMax',6)
! use xyzPhysicalMinMaxDielectric before xyzDielectricMinMax:
! 1.) check for xyzPhysicalMinMaxDielectric
! 2.) check for xyzDielectricMinMax
CALL SelectMinMaxRegion('Dielectric',useDielectricMinMax,&
                        'xyzPhysicalMinMaxDielectric',xyzPhysicalMinMaxDielectric,&
                        'xyzDielectricMinMax',xyzDielectricMinMax)

! display ranges of Dielectric region depending on useDielectricMinMax
!CALL DisplayRanges('useDielectricMinMax',useDielectricMinMax,&
                   !'xyzDielectricMinMax',xyzDielectricMinMax(1:6),&
           !'xyzPhysicalMinMaxDielectric',xyzPhysicalMinMaxDielectric(1:6))

! find all elements in the Dielectric region
IF(useDielectricMinMax)THEN ! find all elements located inside of 'xyzMinMax'
  CALL FindElementInRegion(isDielectricElem,xyzDielectricMinMax,&
                           ElementIsInside=.TRUE.,&
                           DoRadius=DielectricCheckRadius,Radius=DielectricRadiusValue,&
                           DisplayInfo=.TRUE.,&
                           GeometryName=DielectricTestCase,&
                           GeometryAxis=DielectricCircleAxis)
ELSE ! find all elements located outside of 'xyzPhysicalMinMaxDielectric'
  CALL FindElementInRegion(isDielectricElem,xyzPhysicalMinMaxDielectric,&
                           ElementIsInside=.FALSE.,&
                           DoRadius=DielectricCheckRadius,Radius=DielectricRadiusValue,&
                           DisplayInfo=.TRUE.,&
                           GeometryName=DielectricTestCase,&
                           GeometryAxis=DielectricCircleAxis)
END IF

! find all faces in the Dielectric region
CALL FindInterfacesInRegion(isDielectricFace,isDielectricInterFace,isDielectricElem,info_opt='find all faces in the Dielectric region')

! Get number of Dielectric Elems, Faces and Interfaces. Create Mappngs Dielectric <-> physical region
CALL CountAndCreateMappings('Dielectric',&
                            isDielectricElem,isDielectricFace,isDielectricInterFace,&
                            nDielectricElems,nDielectricFaces, nDielectricInterFaces,&
                            ElemToDielectric,DielectricToElem,& ! these two are allocated
                            FaceToDielectric,DielectricToFace,& ! these two are allocated
                            FaceToDielectricInter,DielectricInterToFace,& ! these two are allocated
                            DisplayInfo=.TRUE.)

! Set the dielectric profile function EpsR,MuR=f(x,y,z) in the Dielectric region: only for Maxwell + HDG
! for HDG the volume field is not used, only for output in .h5 file for checking if the region is used correctly
! because in HDG only a constant profile is implemented
CALL SetDielectricVolumeProfile()

#if !(USE_HDG)
  ! Determine dielectric Values on faces and communicate them: only for Maxwell
  CALL SetDielectricFaceProfile()
#else /*if USE_HDG*/
  ! Set HDG diffusion tensor 'chitens' on faces
  CALL SetDielectricFaceProfile_HDG()
  !IF(ANY(IniExactFunc.EQ.(/200,300/)))THEN ! for dielectric sphere/slab case
    ! set dielectric ratio e_io = eps_inner/eps_outer for dielectric sphere depending on wheter
    ! the dielectric reagion is inside the sphere or outside: currently one reagion is assumed vacuum
    IF(useDielectricMinMax)THEN ! dielectric elements are assumed to be located inside of 'xyzMinMax'
      DielectricRatio=DielectricEpsR
    ELSE ! dielectric elements outside of sphere, hence, the inverse value is taken
      DielectricRatio=DielectricEpsR_inv
    END IF
    ! get the axial electric field strength in x-direction of the dielectric sphere setup
    Dielectric_E_0 = GETREAL('Dielectric_E_0')
  !END IF
#endif /*USE_HDG*/

! create a HDF5 file containing the DielectriczetaGlobal field: only for Maxwell
CALL WriteDielectricGlobalToHDF5()

DielectricInitIsDone=.TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT Dielectric DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')
END SUBROUTINE InitDielectric


SUBROUTINE SetDielectricVolumeProfile()
!===================================================================================================================================
! Determine the local Dielectric damping factor in x,y and z-direction using a constant/linear/polynomial/... function
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Mesh_Vars,            ONLY: Elem_xGP
USE MOD_Dielectric_Vars,      ONLY: DielectricEps,DielectricMu,DielectricConstant_inv
USE MOD_Dielectric_Vars,      ONLY: nDielectricElems,DielectricToElem
USE MOD_Dielectric_Vars,      ONLY: DielectricRmax,DielectricEpsR,DielectricMuR,DielectricTestCase
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER             :: i,j,k,iDielectricElem
REAL                :: r
!===================================================================================================================================
! Check if there are dielectric elements
IF(nDielectricElems.LT.1) RETURN

! Allocate field variables
ALLOCATE(         DielectricEps(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems))
ALLOCATE(          DielectricMu(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems))
ALLOCATE(DielectricConstant_inv(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems))
DielectricEps=0.
DielectricMu=0.
DielectricConstant_inv=0.

! Fish eye lens: half sphere filled with gradually changing dielectric medium
IF(TRIM(DielectricTestCase).EQ.'FishEyeLens')THEN
  ! use function with radial dependence: EpsR=n0^2 / (1 + (r/r_max)^2)^2
  DO iDielectricElem=1,nDielectricElems; DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r = SQRT(Elem_xGP(1,i,j,k,DielectricToElem(iDielectricElem))**2+&
             Elem_xGP(2,i,j,k,DielectricToElem(iDielectricElem))**2+&
             Elem_xGP(3,i,j,k,DielectricToElem(iDielectricElem))**2  )
    DielectricEps(i,j,k,iDielectricElem) = 4./((1+(r/DielectricRmax)**2)**2)
  END DO; END DO; END DO; END DO !iDielectricElem,k,j,i
  DielectricMu(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems) = DielectricMuR

ELSE ! simply set values const.
  DO iDielectricElem=1,nDielectricElems; DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    DielectricEps(i,j,k,1:iDielectricElem) = DielectricEpsR
    DielectricMu( i,j,k,1:iDielectricElem) = DielectricMuR
  END DO; END DO; END DO; END DO !iDielectricElem,k,j,i
END IF

! invert the product of EpsR and MuR
DielectricConstant_inv(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems) = 1./& ! 1./(EpsR*MuR)
                                                                 (DielectricEps(0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems)*&
                                                                  DielectricMu( 0:PP_N,0:PP_N,0:PP_N,1:nDielectricElems))

! check if MPI local values differ for HDG only (variable dielectric values are not implemented)
#if USE_HDG
IF(.NOT.ALMOSTEQUALRELATIVE(MAXVAL(DielectricEps(:,:,:,:)),MINVAL(DielectricEps(:,:,:,:)),1e-8))THEN
  IF(nDielectricElems.GT.0)THEN
    CALL abort(&
        __STAMP__&
        ,'Dielectric material values in HDG solver cannot be spatially variable because this feature is not implemented! Delta Eps_R=',&
    RealInfoOpt=MAXVAL(DielectricEps(:,:,:,:))-MINVAL(DielectricEps(:,:,:,:)))
  END IF
END IF
IF(.NOT.ALMOSTEQUALRELATIVE(MAXVAL(DielectricMu(:,:,:,:)),MINVAL(DielectricMu(:,:,:,:)),1e-8))THEN
  IF(nDielectricElems.GT.0)THEN
    CALL abort(&
        __STAMP__&
        ,'Dielectric material values in HDG solver cannot be spatially variable because this feature is not implemented! Delta Mu_R=',&
    RealInfoOpt=MAXVAL(DielectricMu(:,:,:,:))-MINVAL(DielectricMu(:,:,:,:)))
  END IF
END IF
#endif /*USE_HDG*/
END SUBROUTINE SetDielectricVolumeProfile


#if !(USE_HDG)
SUBROUTINE SetDielectricFaceProfile()
!===================================================================================================================================
!> Set the dielectric factor 1./SQRT(EpsR*MuR) for each face DOF in the array "Dielectric_Master".
!> Only the array "Dielectric_Master" is used in the Riemann solver, as only the master calculates the flux array
!> (maybe slave information is used in the future)
!>
!> Note:
!> for MPI communication, the data on the faces has to be stored in an array which is completely sent to the corresponding MPI
!> threads (one cannot simply send parts of an array using, e.g., "2:5" for an allocated array of dimension "1:5" because this
!> is not allowed)
!> re-map data from dimension PP_nVar (due to prolong to face routine) to 1 (only one dimension is needed to transfer the
!> information)
!> This could be overcome by using template subroutines .t90 (see FlexiOS)
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Dielectric_Vars, ONLY:DielectricConstant_inv,Dielectric_Master,Dielectric_Slave,isDielectricElem,ElemToDielectric
USE MOD_Mesh_Vars,       ONLY:nSides
USE MOD_ProlongToFace,   ONLY:ProlongToFace
#if USE_MPI
USE MOD_MPI_Vars
USE MOD_MPI,             ONLY:StartReceiveMPIData,StartSendMPIData,FinishExchangeMPIData
#endif
USE MOD_FillMortar,      ONLY:U_Mortar
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLE,Dielectric_dummy_Master2S
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,1:nSides)           :: Dielectric_dummy_Master
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,1:nSides)           :: Dielectric_dummy_Slave
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems) :: Dielectric_dummy_elem
#if USE_MPI
REAL,DIMENSION(1,0:PP_N,0:PP_N,1:nSides)                 :: Dielectric_dummy_Master2
REAL,DIMENSION(1,0:PP_N,0:PP_N,1:nSides)                 :: Dielectric_dummy_Slave2
INTEGER                                                  :: I,J,iSide
#endif /*USE_MPI*/
INTEGER                                                  :: iElem
!===================================================================================================================================
! General workflow:
! 1.  Initialize dummy arrays for Elem/Face
! 2.  Fill dummy element values for non-Dielectric sides
! 3.  Map dummy element values to face arrays (prolong to face needs data of dimension PP_nVar)
! 4.  For MPI communication, the data on the faces has to be stored in an array which is completely sent to the corresponding MPI
!     threads (one cannot simply send parts of an array using, e.g., "2:5" for an allocated array of dimension "1:5" because this
!     is not allowed)
!     re-map data from dimension PP_nVar (due to prolong to face routine) to 1 (only one dimension is needed to transfer the
!     information)
! 5.  Send/Receive MPI data
! 6.  Allocate the actually needed arrays containing the dielectric material information on the sides
! 7.  With MPI, use dummy array which was used for sending the MPI data
!     or with single execution, directly use prolonged data on face
! 8.  Check if the default value remains unchanged (negative material constants are not allowed until now)

! 1.  Initialize dummy arrays for Elem/Face
Dielectric_dummy_elem    = -1.
Dielectric_dummy_Master  = -1.
Dielectric_dummy_Slave   = -1.

! 2.  Fill dummy element values for non-Dielectric sides
DO iElem=1,PP_nElems
  IF(isDielectricElem(iElem))THEN
    ! set only the first dimension to 1./SQRT(EpsR*MuR) (the rest are dummies)
    Dielectric_dummy_elem(1,0:PP_N,0:PP_N,0:PP_N,(iElem))=SQRT(DielectricConstant_inv(0:PP_N,0:PP_N,0:PP_N,ElemToDielectric(iElem)))
  ELSE
    Dielectric_dummy_elem(1,0:PP_N,0:PP_N,0:PP_N,(iElem))=1.0
  END IF
END DO

!3.   Map dummy element values to face arrays (prolong to face needs data of dimension PP_nVar)
CALL ProlongToFace(Dielectric_dummy_elem,Dielectric_dummy_Master,Dielectric_dummy_Slave,doMPISides=.FALSE.)
CALL U_Mortar(Dielectric_dummy_Master,Dielectric_dummy_Slave,doMPISides=.FALSE.)
#if USE_MPI
  CALL ProlongToFace(Dielectric_dummy_elem,Dielectric_dummy_Master,Dielectric_dummy_Slave,doMPISides=.TRUE.)
  CALL U_Mortar(Dielectric_dummy_Master,Dielectric_dummy_Slave,doMPISides=.TRUE.)

  ! 4.  For MPI communication, the data on the faces has to be stored in an array which is completely sent to the corresponding MPI
  !     threads (one cannot simply send parts of an array using, e.g., "2:5" for an allocated array of dimension "1:5" because this
  !     is not allowed)
  !     re-map data from dimension PP_nVar (due to prolong to face routine) to 1 (only one dimension is needed to transfer the
  !     information)
  Dielectric_dummy_Master2 = 0.
  Dielectric_dummy_Slave2  = 0.
  DO I=0,PP_N
    DO J=0,PP_N
      DO iSide=1,nSides
        Dielectric_dummy_Master2(1,I,J,iSide)=Dielectric_dummy_Master(1,I,J,iSide)
        Dielectric_dummy_Slave2 (1,I,J,iSide)=Dielectric_dummy_Slave( 1,I,J,iSide)
      END DO
    END DO
  END DO

  ! 5.  Send Slave Dielectric info (real array with dimension (N+1)*(N+1)) to Master procs
  CALL StartReceiveMPIData(1,Dielectric_dummy_Slave2 ,1,nSides ,RecRequest_U2,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,Dielectric_dummy_Slave2 ,1,nSides,SendRequest_U2,SendID=2) ! Send YOUR

  ! Send Master Dielectric info (real array with dimension (N+1)*(N+1)) to Slave procs
  CALL StartReceiveMPIData(1,Dielectric_dummy_Master2,1,nSides ,RecRequest_U ,SendID=1) ! Receive YOUR
  CALL StartSendMPIData(   1,Dielectric_dummy_Master2,1,nSides,SendRequest_U ,SendID=1) ! Send MINE

  CALL FinishExchangeMPIData(SendRequest_U2,RecRequest_U2,SendID=2) !Send MINE - receive YOUR
  CALL FinishExchangeMPIData(SendRequest_U, RecRequest_U ,SendID=1) !Send YOUR - receive MINE
#endif /*USE_MPI*/

! 6.  Allocate the actually needed arrays containing the dielectric material information on the sides
ALLOCATE(Dielectric_Master(0:PP_N,0:PP_N,1:nSides))
ALLOCATE(Dielectric_Slave( 0:PP_N,0:PP_N,1:nSides))


! 7.  With MPI, use dummy array which was used for sending the MPI data
!     or with single execution, directly use prolonged data on face
#if USE_MPI
  Dielectric_Master=Dielectric_dummy_Master2(1,0:PP_N,0:PP_N,1:nSides)
  Dielectric_Slave =Dielectric_dummy_Slave2( 1,0:PP_N,0:PP_N,1:nSides)
#else
  Dielectric_Master=Dielectric_dummy_Master(1,0:PP_N,0:PP_N,1:nSides)
  Dielectric_Slave =Dielectric_dummy_Slave( 1,0:PP_N,0:PP_N,1:nSides)
#endif /*USE_MPI*/

! 8.  Check if the default value remains unchanged (negative material constants are not allowed until now)
IF(MINVAL(Dielectric_Master).LT.0.0)THEN
  CALL abort(&
  __STAMP__&
  ,'Dielectric material values for Riemann solver not correctly determined. MINVAL(Dielectric_Master)=',&
  RealInfoOpt=MINVAL(Dielectric_Master))
END IF
END SUBROUTINE SetDielectricFaceProfile
#endif /* not USE_HDG*/


#if USE_HDG
SUBROUTINE SetDielectricFaceProfile_HDG()
!===================================================================================================================================
! set the dielectric factor EpsR for each face DOF in the array "chitens" (constant. on the diagonal matrix)
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Dielectric_Vars, ONLY:isDielectricElem,DielectricEpsR
USE MOD_Equation_Vars,   ONLY:chitens,chitensInv,chitens_face
USE MOD_Mesh_Vars,       ONLY:nInnerSides
USE MOD_Mesh_Vars,       ONLY:ElemToSide
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
INTEGER :: i,j,k,iElem
INTEGER :: p,q,flip,locSideID,SideID
REAL    :: Invdummy(3,3)
!===================================================================================================================================
DO iElem=1,PP_nElems
  ! cycle the loop if no dielectric element is connected to the side
  IF(.NOT.isDielectricElem(iElem)) CYCLE

  !compute field on Gauss-Lobatto points (continuous!)
  DO k=0,PP_N ; DO j=0,PP_N ; DO i=0,PP_N
    !CALL CalcChiTens(Elem_xGP(:,i,j,k,iElem),chitens(:,:,i,j,k,iElem),chitensInv(:,:,i,j,k,iElem),DielectricEpsR)
    CALL CalcChiTens(chitens(:,:,i,j,k,iElem),chitensInv(:,:,i,j,k,iElem),DielectricEpsR)
  END DO; END DO; END DO !i,j,k

  DO locSideID=1,6
    flip=ElemToSide(E2S_FLIP,LocSideID,iElem)
    SideID=ElemToSide(E2S_SIDE_ID,LocSideID,iElem)
    IF(.NOT.((flip.NE.0).AND.(SideID.LE.nInnerSides)))THEN
      DO q=0,PP_N; DO p=0,PP_N
        !CALL CalcChiTens(Face_xGP(:,p,q),chitens_face(:,:,p,q,SideID),Invdummy(:,:),DielectricEpsR)
        CALL CalcChiTens(chitens_face(:,:,p,q,SideID),Invdummy(:,:),DielectricEpsR)
      END DO; END DO !p, q
    END IF
  END DO !locSideID
END DO
END SUBROUTINE SetDielectricFaceProfile_HDG


SUBROUTINE CalcChiTens(chitens,chitensInv,DielectricEpsR)
!===================================================================================================================================
! calculate diffusion tensor, diffusion coefficient chi1/chi0 along B vector field plus isotropic diffusion 1.
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Basis,         ONLY:GetInverse
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)                 :: DielectricEpsR
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                :: chitens(3,3)
REAL,INTENT(OUT),OPTIONAL       :: chitensInv(3,3)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
! default
chitens=0.
chitens(1,1)=1.
chitens(2,2)=1.
chitens(3,3)=1.

! set diffusion tensor: currently only constant distribution
chitens(1,1)=DielectricEpsR
chitens(2,2)=DielectricEpsR
chitens(3,3)=DielectricEpsR

! inverse of diffusion 3x3 tensor on each gausspoint
chitensInv(:,:)=getInverse(3,chitens(:,:))

END SUBROUTINE calcChiTens
#endif /*USE_HDG*/



SUBROUTINE FinalizeDielectric()
!===================================================================================================================================
!
!===================================================================================================================================
! MODULES
USE MOD_Dielectric_Vars,            ONLY: DoDielectric,DielectricEps,DielectricMu
USE MOD_Dielectric_Vars,            ONLY: ElemToDielectric,DielectricToElem,isDielectricElem
USE MOD_Dielectric_Vars,            ONLY: FaceToDielectric,DielectricToFace,isDielectricFace
USE MOD_Dielectric_Vars,            ONLY: FaceToDielectricInter,DielectricInterToFace,isDielectricInterFace
USE MOD_Dielectric_Vars,            ONLY: DielectricConstant_inv,Dielectric_Master,Dielectric_Slave
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
!RETURN
IF(.NOT.DoDielectric) RETURN
SDEALLOCATE(DielectricEps)
SDEALLOCATE(DielectricMu)
SDEALLOCATE(DielectricToElem)
SDEALLOCATE(ElemToDielectric)
SDEALLOCATE(DielectricToFace)
SDEALLOCATE(FaceToDielectricInter)
SDEALLOCATE(DielectricInterToFace)
SDEALLOCATE(FaceToDielectric)
SDEALLOCATE(isDielectricElem)
SDEALLOCATE(isDielectricFace)
SDEALLOCATE(isDielectricInterFace)
SDEALLOCATE(DielectricConstant_inv)
SDEALLOCATE(Dielectric_Master)
SDEALLOCATE(Dielectric_Slave)
END SUBROUTINE FinalizeDielectric





END MODULE MOD_Dielectric
