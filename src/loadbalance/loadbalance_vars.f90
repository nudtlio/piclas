MODULE MOD_LoadBalance_Vars
!===================================================================================================================================
! Variables needed for the evaluation of the record points
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PUBLIC
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
LOGICAL                             :: DoLoadBalance                              ! DoLoadBalance
LOGICAL                             :: InitLoadBalanceIsDone                      ! switch for checking
! time measurement
REAL,ALLOCATABLE                    :: tTotal(:)                                  ! time measurement over whole dt_analyze 
REAL,ALLOCATABLE                    :: tCurrent(:)                                ! time measurement over one step
REAL,ALLOCATABLE                    :: LoadSum(:)                                 ! sum of load per step over whole dt_analyze 
REAL(KIND=8)                        :: nTotalParts                                ! number of particles in time of tTotal
INTEGER                             :: nLoadIter                                  ! number of load iter 
!INTEGER                             :: nCurrentParts                              ! number of current particles
INTEGER                             :: nLoadBalance                               ! number of load balances
LOGICAL                             :: OutputRank                                 ! output rank
REAL,ALLOCATABLE                    :: LoadDistri(:)                              ! Weighted load distribution of all procs
INTEGER,ALLOCATABLE                 :: PartDistri(:)                              ! Part distribution of all procs
INTEGER                             :: PartWeightMethod                           ! method to compute the particle weight
INTEGER                             :: WeightAverageMethod                        ! method to average the particle weight
                                                                                  ! (1: iter, 2: dt_Analyze)
END MODULE MOD_LoadBalance_Vars
