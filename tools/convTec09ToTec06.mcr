#!MC 1100
$!VarSet |MFBD| = 'FOLDER_PLACEHOLDER'
$!READDATASET  'DATA_PLACEHOLDER ' 
  READDATAOPTION = NEW
  RESETSTYLE = YES
  INCLUDETEXT = NO
  INCLUDEGEOM = NO
  INCLUDECUSTOMLABELS = NO
  VARLOADMODE = BYNAME
  ASSIGNSTRANDIDS = YES
  INITIALPLOTTYPE = CARTESIAN3D
  VARNAMELIST = '"X" "Y" "Z" "ElectricFieldX" "ElectricFieldY" "ElectricFieldZ" "MagneticFieldX" "MagneticFieldY" "MagneticFieldZ" "Phi" "Psi"' 
$!WRITEDATASET  "|MFBD|OUTPUT_PLACEHOLDER.plt" 
  INCLUDETEXT = NO
  INCLUDEGEOM = NO
  INCLUDECUSTOMLABELS = NO
  BINARY = YES
  USEPOINTFORMAT = NO
  PRECISION = 9
$!RemoveVar |MFBD|
