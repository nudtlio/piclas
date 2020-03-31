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

MODULE MOD_DSMC_Relaxation
!===================================================================================================================================
! Module including collisions, relaxation and reaction decision
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
PUBLIC :: DSMC_VibRelaxDiatomic, CalcMeanVibQuaDiatomic, CalcXiVibPart, CalcXiTotalEqui
!===================================================================================================================================

CONTAINS

SUBROUTINE DSMC_VibRelaxDiatomic(iPair, iPart, FakXi)
!===================================================================================================================================
! Performs the vibrational relaxation of diatomic molecules
!===================================================================================================================================
! MODULES
USE MOD_DSMC_Vars             ,ONLY: DSMC, SpecDSMC, PartStateIntEn, Coll_pData, RadialWeighting
USE MOD_Globals_Vars          ,ONLY: BoltzmannConst
USE MOD_Particle_Vars         ,ONLY: PartSpecies, VarTimeStep
USE MOD_part_tools            ,ONLY: GetParticleWeight
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)           :: iPart, iPair
REAL, INTENT(IN)              :: FakXi
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                          :: MaxColQua, iRan, Ec
INTEGER                       :: iQuaMax, iQua
!===================================================================================================================================
IF (RadialWeighting%DoRadialWeighting.OR.VarTimeStep%UseVariableTimeStep) THEN
  Ec = Coll_pData(iPair)%Ec / GetParticleWeight(iPart)
ELSE
  Ec = Coll_pData(iPair)%Ec
END IF

MaxColQua = Ec/(BoltzmannConst*SpecDSMC(PartSpecies(iPart))%CharaTVib)  &
          - DSMC%GammaQuant
iQuaMax = MIN(INT(MaxColQua) + 1, SpecDSMC(PartSpecies(iPart))%MaxVibQuant)
CALL RANDOM_NUMBER(iRan)
iQua = INT(iRan * iQuaMax)
CALL RANDOM_NUMBER(iRan)
DO WHILE (iRan.GT.(1 - REAL(iQua)/REAL(MaxColQua))**FakXi)
  !laux diss page 31
  CALL RANDOM_NUMBER(iRan)
  iQua = INT(iRan * iQuaMax)
  CALL RANDOM_NUMBER(iRan)
END DO
PartStateIntEn(1,iPart) = (iQua + DSMC%GammaQuant) * BoltzmannConst &
              * SpecDSMC(PartSpecies(iPart))%CharaTVib

END SUBROUTINE DSMC_VibRelaxDiatomic


SUBROUTINE CalcMeanVibQuaDiatomic()
!===================================================================================================================================
! Computes the mean vibrational quantum number of diatomic species in a cell each iteration;
! ChemReac%MeanEVibQua_PerIter is required for the determination of the vibrational degree of freedom, only used for diatomic
! molecules. For the polyatomic case, the actual vibrational degree of freedom of each molecule is utilized and not a mean value.
! The values for polyatomic molecules can have a greater spread, thus a mean value can prohibit reactions of highly excited
! molecules at lower average temperatures.
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars,          ONLY : BoltzmannConst
USE MOD_DSMC_Vars,             ONLY : DSMC, CollInf, SpecDSMC, ChemReac, BGGas
USE MOD_Particle_Vars,         ONLY : nSpecies
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER         :: iSpec
REAL            :: iRan, VibQuaTemp
!===================================================================================================================================

DO iSpec = 1, nSpecies
  IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
    IF(.NOT.SpecDSMC(iSpec)%PolyatomicMol) THEN
      ! Skip the background gas species (value initialized in dsmc_chemical_init.f90)
      IF(BGGas%BackgroundSpecies(iSpec)) CYCLE
      ! Only treat species present in the cell
      IF(CollInf%Coll_SpecPartNum(iSpec).GT.0) THEN
        ChemReac%MeanEVib_PerIter(iSpec) = ChemReac%MeanEVib_PerIter(iSpec) / CollInf%Coll_SpecPartNum(iSpec)
        VibQuaTemp = ChemReac%MeanEVib_PerIter(iSpec) / (BoltzmannConst*SpecDSMC(iSpec)%CharaTVib) - DSMC%GammaQuant
        CALL RANDOM_NUMBER(iRan)
        IF((VibQuaTemp-INT(VibQuaTemp)).GT.iRan) THEN
          ChemReac%MeanEVibQua_PerIter(iSpec) = MIN(INT(VibQuaTemp) + 1, SpecDSMC(iSpec)%MaxVibQuant-1)
        ELSE
          ChemReac%MeanEVibQua_PerIter(iSpec) = MIN(INT(VibQuaTemp), SpecDSMC(iSpec)%MaxVibQuant-1)
        END IF
        IF(ChemReac%MeanEVibQua_PerIter(iSpec).GT.0) THEN
          ChemReac%MeanXiVib_PerIter(iSpec) = 2. * ChemReac%MeanEVibQua_PerIter(iSpec) &
                                            * LOG(1.0/ChemReac%MeanEVibQua_PerIter(iSpec) + 1.0 )
        ELSE
          ChemReac%MeanXiVib_PerIter(iSpec) = 0.
        END IF
      ELSE
        ChemReac%MeanEVibQua_PerIter(iSpec) = 0
        ChemReac%MeanXiVib_PerIter(iSpec) = 0.
      END IF  ! CollInf%Coll_SpecPartNum(iSpec).GT.0
    END IF    ! .NOT.SpecDSMC(iSpec)%PolyatomicMol
  END IF      ! (SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)
END DO        ! iSpec = 1, nSpecies

END SUBROUTINE CalcMeanVibQuaDiatomic


SUBROUTINE CalcXiVibPart(TVib, iSpec, XiVibPart)
!===================================================================================================================================
! Calculation of the vibrational degrees of freedom for each characteristic vibrational temperature, used for chemical reactions
!===================================================================================================================================
! MODULES
  USE MOD_DSMC_Vars,              ONLY : SpecDSMC, PolyatomMolDSMC
! IMPLICIT VARIABLE HANDLING
  IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
  REAL, INTENT(IN)                :: TVib  !
  INTEGER, INTENT(IN)             :: iSpec      ! Number of Species
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
  REAL, INTENT(OUT)               :: XiVibPart(:)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
  INTEGER                         :: iDOF, iPolyatMole
!===================================================================================================================================

  IF(SpecDSMC(iSpec)%PolyatomicMol) THEN
    iPolyatMole = SpecDSMC(iSpec)%SpecToPolyArray
    XiVibPart = 0.0
    ! The vibrational energy of the dissociating molecule and the char. vib. temps of the product are used to determine a
    ! first guess for the vibrational degree of freedom
    DO iDOF = 1 , PolyatomMolDSMC(iPolyatMole)%VibDOF
      XiVibPart(iDOF) = (2.0*PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF) / TVib) &
                / (EXP(PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/ TVib) - 1.0)
    END DO
  ELSE
    XiVibPart(1) = (2.0*SpecDSMC(iSpec)%CharaTVib / TVib) &
              / (EXP(SpecDSMC(iSpec)%CharaTVib / TVib) - 1.0)
  END IF
  RETURN

END SUBROUTINE CalcXiVibPart


SUBROUTINE CalcXiTotalEqui(iReac, iPair, Xi_rel, Weight1, Weight2, WeightProd, XiVibPart, XiElecPart)
!===================================================================================================================================
! Calculation of the vibrational degrees of freedom for each characteristic vibrational temperature, used for chemical reactions
!===================================================================================================================================
! MODULES
  USE MOD_Globals_Vars,           ONLY : BoltzmannConst
  USE MOD_DSMC_Vars,              ONLY : SpecDSMC, PolyatomMolDSMC, ChemReac, Coll_pData, DSMC
! IMPLICIT VARIABLE HANDLING
  IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
  INTEGER, INTENT(IN)             :: iReac, iPair      ! Reaction Number, Grow a pair number
  REAL, INTENT(IN)                :: Xi_rel, Weight1, Weight2, WeightProd
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
  REAL, INTENT(OUT), OPTIONAL     :: XiVibPart(:,:), XiElecPart(1:3)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
  INTEGER                         :: iDOF, iPolyatMole, nProd, iProd, iQua
  INTEGER                         :: ProductReac(1:3)
  REAL                            :: ETotal, EZeroPoint, EGuess, Xi_Total, LowerTemp, UpperTemp, MiddleTemp, Xi_TotalTemp
  REAL                            :: SumOne, SumTwo, Weight(1:3)
  REAL                            :: eps_prec=0.1
!===================================================================================================================================

  ProductReac(1:3) = ChemReac%DefinedReact(iReac,2,1:3)

  IF(ProductReac(3).EQ.0) THEN
    Xi_Total = Xi_rel + SpecDSMC(ProductReac(1))%Xi_Rot + SpecDSMC(ProductReac(2))%Xi_Rot
    nProd = 2
  ELSE
    Xi_Total = Xi_rel + SpecDSMC(ProductReac(1))%Xi_Rot + SpecDSMC(ProductReac(2))%Xi_Rot + SpecDSMC(ProductReac(3))%Xi_Rot
    nProd = 3
  END IF

  Weight(1) = Weight1; Weight(2) = Weight2; Weight(3) = WeightProd

  ! Weighted total collision energy
  ETotal = Coll_pData(iPair)%Ec

  EZeroPoint = 0.0
  DO iProd = 1, nProd
    EZeroPoint = EZeroPoint + SpecDSMC(ProductReac(iProd))%EZeroPoint * Weight(iProd)
  END DO

  LowerTemp = 1.0
  UpperTemp = 2.*(ETotal - EZeroPoint) * nProd / SUM(Weight) / (Xi_Total * BoltzmannConst)
  DO WHILE ( ABS( UpperTemp - LowerTemp ) .GT. eps_prec )
    MiddleTemp = 0.5*( LowerTemp + UpperTemp)
    Xi_TotalTemp = Xi_Total
    DO iProd = 1, nProd
      IF((SpecDSMC(ProductReac(iProd))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(iProd))%InterID.EQ.20)) THEN
        IF(SpecDSMC(ProductReac(iProd))%PolyatomicMol) THEN
          iPolyatMole = SpecDSMC(ProductReac(iProd))%SpecToPolyArray
          XiVibPart(iProd,:) = 0.0
          ! The vibrational energy of the dissociating molecule and the char. vib. temps of the product are used to determine a
          ! first guess for the vibrational degree of freedom
          DO iDOF = 1 , PolyatomMolDSMC(iPolyatMole)%VibDOF
            ! Leave the root-finding algorithm if the exponent is above machine precision
            IF(PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/ MiddleTemp.GT.RANGE(MiddleTemp)) THEN
              XiVibPart = 0.0
              RETURN
            END IF
            XiVibPart(iProd,iDOF) = (2.0*PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF) / MiddleTemp) &
                      / (EXP(PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/ MiddleTemp) - 1.0)
            Xi_TotalTemp = Xi_TotalTemp + XiVibPart(iProd,iDOF)
          END DO
        ELSE
          ! Leave the root-finding algorithm if the exponent is above machine precision
          IF(SpecDSMC(ProductReac(iProd))%CharaTVib / MiddleTemp.GT.RANGE(MiddleTemp)) THEN
            XiVibPart = 0.0
            RETURN
          END IF
          XiVibPart(iProd,1) = (2.0*SpecDSMC(ProductReac(iProd))%CharaTVib / MiddleTemp) &
                    / (EXP(SpecDSMC(ProductReac(iProd))%CharaTVib / MiddleTemp) - 1.0)
          Xi_TotalTemp = Xi_TotalTemp + XiVibPart(iProd,1)
        END IF
      ELSE
        IF(PRESENT(XiVibPart)) XiVibPart(iProd,:) = 0.0
      END IF
      IF(DSMC%ElectronicModel) THEN
        IF((SpecDSMC(ProductReac(iProd))%InterID.NE.4).AND.(.NOT.SpecDSMC(ProductReac(iProd))%FullyIonized)) THEN
          SumOne = 0.0
          SumTwo = 0.0
          DO iQua = 0, SpecDSMC(ProductReac(iProd))%MaxElecQuant-1
            ! Avoid overflows by skipping the respective electronic states in the sum (equivalent to adding a zero)
            IF(SpecDSMC(ProductReac(iProd))%ElectronicState(2,iQua)/MiddleTemp.GT.RANGE(MiddleTemp)) THEN
              CYCLE
            END IF
            SumOne = SumOne + SpecDSMC(ProductReac(iProd))%ElectronicState(1,iQua)*BoltzmannConst &
                            * SpecDSMC(ProductReac(iProd))%ElectronicState(2,iQua)  &
                            * EXP(-SpecDSMC(ProductReac(iProd))%ElectronicState(2,iQua)/MiddleTemp)
            SumTwo = SumTwo + SpecDSMC(ProductReac(iProd))%ElectronicState(1,iQua) &
                            * EXP(-SpecDSMC(ProductReac(iProd))%ElectronicState(2,iQua)/MiddleTemp)
          END DO
          IF((SumOne.GT.0.0).AND.(SumTwo*BoltzmannConst.GT.0.0)) THEN
            XiElecPart(iProd) = 2. * SumOne / (SumTwo * BoltzmannConst * MiddleTemp)
            Xi_TotalTemp = Xi_TotalTemp + XiElecPart(iProd)
          ELSE
            XiElecPart(iProd) = 0.0
          END IF
        ELSE
          IF(PRESENT(XiElecPart)) XiElecPart(iProd) = 0.0
        END IF
      END IF
    END DO
    EGuess = EZeroPoint + Xi_TotalTemp / 2. * BoltzmannConst * MiddleTemp * SUM(Weight) / nProd
    IF (EGuess .GT. ETotal) THEN
      UpperTemp = MiddleTemp
    ELSE
      LowerTemp = MiddleTemp
    END IF
  END DO
  RETURN

END SUBROUTINE CalcXiTotalEqui

END MODULE MOD_DSMC_Relaxation
