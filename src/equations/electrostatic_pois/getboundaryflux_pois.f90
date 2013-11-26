#include "boltzplatz.h"

MODULE MOD_GetBoundaryFlux_Pois
!===================================================================================================================================
! Contains FillBoundary (which depends on the considered equation)
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------

! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE GetBoundaryFlux_Pois
  MODULE PROCEDURE GetBoundaryFlux
END INTERFACE


PUBLIC::GetBoundaryFlux_Pois
!===================================================================================================================================

CONTAINS



SUBROUTINE GetBoundaryFlux(F_Face,BCType,BCState,xGP_Face,normal,tangent1,tangent2,t,tDeriv,U_Face,iSide)
!===================================================================================================================================
! Computes the boundary values for a given Cartesian mesh face (defined by FaceID)
! BCType: 1...periodic, 2...exact BC
! Attention 1: this is only a tensor of local values U_Face and has to be stored into the right U_Left or U_Right in
!              SUBROUTINE CalcSurfInt
! Attention 2: U_FacePeriodic is only needed in the case of periodic boundary conditions
!===================================================================================================================================
! MODULES
USE MOD_Globals,ONLY:Abort
USE MOD_PreProc
USE MOD_Riemann_Pois,ONLY:Riemann_Pois
USE MOD_Equation,ONLY:ExactFunc
USE MOD_Equation_Vars, ONLY:c,c_inv
USE MOD_Particle_Vars,ONLY: PartBound
USE MOD_Mesh_Vars,ONLY:BC
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)                  :: BCType,BCState
REAL,INTENT(INOUT)                   :: U_Face(PP_nVar,0:PP_N,0:PP_N)
REAL,INTENT(IN)                      :: xGP_Face(3,0:PP_N,0:PP_N)
REAL,INTENT(IN)                      :: normal(3,0:PP_N,0:PP_N)
REAL,INTENT(IN)                      :: tangent1(3,0:PP_N,0:PP_N)
REAL,INTENT(IN)                      :: tangent2(3,0:PP_N,0:PP_N)
REAL,INTENT(IN)                      :: t
INTEGER,INTENT(IN)                   :: tDeriv
INTEGER,INTENT(IN)                   :: iSide
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                     :: F_Face(PP_nVar,0:PP_N,0:PP_N)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                              :: p,q
REAL                                 :: n_loc(3),resul(PP_nVar)
REAL                                 :: U_Face_loc(PP_nVar,0:PP_N,0:PP_N)
!===================================================================================================================================
SELECT CASE(BCType)
CASE(1) !Periodic already filled!
CASE(2) ! exact BC = Dirichlet BC !!
  ! Determine the exact BC state
  DO q=0,PP_N
    DO p=0,PP_N
      CALL ExactFunc(BCState,t,tDeriv,xGP_Face(:,p,q),U_Face_loc(:,p,q))
    END DO ! p
  END DO ! q
  ! Dirichlet means that we use the gradients from inside the grid cell
  CALL Riemann_Pois(F_Face(:,:,:),U_Face(:,:,:),U_Face_loc(:,:,:),         &
               normal(:,:,:),tangent1(:,:,:),tangent2(:,:,:))

CASE(3) ! 1st order absorbing BC
  U_Face_loc=0.

!  DO q=0,PP_N
!    DO p=0,PP_N
!      resul=U_Face(:,p,q)
!      n_loc=normal(:,p,q)   
!!      U_Face_loc(1,p,q) = resul(1) - c*DOT_PRODUCT(resul(2:4),n_loc)
!      U_Face_loc(2:4,p,q) = -resul(2:4) + c_inv*U_Face(1,p,q)*normal(1:3,p,q)

!    END DO ! p
!  END DO

  CALL Riemann_Pois(F_Face(:,:,:),U_Face(:,:,:),U_Face_loc(:,:,:),         &
               normal(:,:,:),tangent1(:,:,:),tangent2(:,:,:))
  
CASE(4) ! perfectly conducting surface (MunzOmnesSchneider 2000, pp. 97-98)
  ! Determine the exact BC state
  DO q=0,PP_N
    DO p=0,PP_N
      resul=U_Face(:,p,q)
      n_loc=normal(:,p,q)    
    ! U_Face_loc(1,p,q) = 2. * 1000. - resul(1)  !- c*DOT_PRODUCT(resul(2:4),n_loc)
      U_Face_loc(1,p,q) = 2. * PartBound%Voltage(BC(iSide)) - resul(1)  !+ c*DOT_PRODUCT(resul(2:4),n_loc)
      U_Face_loc(2:4,p,q) = + resul(2:4) !- 1./c*resul(1)*n_loc
    END DO ! p
  
  END DO ! q
  ! Dirichlet means that we use the gradients from inside the grid cell
!print*,resul(1)
!      read*
  CALL Riemann_Pois(F_Face(:,:,:),U_Face(:,:,:),U_Face_loc(:,:,:),         &
               normal(:,:,:),tangent1(:,:,:),tangent2(:,:,:))

CASE DEFAULT ! unknown BCType
  CALL abort(__STAMP__,&
       'no BC defined in maxwell/getboundaryflux.f90!',999,999.)
END SELECT ! BCType
END SUBROUTINE GetBoundaryFlux


END MODULE MOD_GetBoundaryFlux_Pois