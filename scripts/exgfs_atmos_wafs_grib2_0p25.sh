#!/bin/sh
######################################################################
#  UTILITY SCRIPT NAME :  exgfs_atmos_wafs_grib2_0p25.sh
#         DATE WRITTEN :  03/20/2020
#
#  Abstract:  This utility script produces the WAFS GRIB2 at 0.25 degree.
#             The output GRIB files are posted on NCEP ftp server and the
#             grib2 files are pushed via dbnet to TOC to WAFS (ICSC).  
#             This is a joint project of WAFC London and WAFC Washington.
#
#             We are processing WAFS grib2 for ffhr from 06 - 36 
#             with 3-hour time increment.
#
# History:  
#####################################################################
echo "-----------------------------------------------------"
echo "JGFS_ATMOS_WAFS_GRIB2_0P25 at 00Z/06Z/12Z/18Z GFS postprocessing"
echo "-----------------------------------------------------"
echo "History: MARCH  2020 - First implementation of this new script."
echo " "
#####################################################################

cd $DATA

set -x

export SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`
export ffhr=$SHOUR
while test $ffhr -le $EHOUR
do
  export ffhr="$(printf "%02d" $(( 10#$ffhr )) )"
  # file name and forecast hour of GFS model data in Grib2 are 3 digits
  export ffhr000="$(printf "%03d" $(( 10#$ffhr )) )"
##########################################################
# Wait for the availability of the gfs WAFS file
##########################################################

  # 3D data (Icing, Turbulence) and 2D data (CB)
  wafs2=$COMIN/${RUN}.${cycle}.wafs.grb2f${ffhr000}
  wafs2i=$COMIN/${RUN}.${cycle}.wafs.grb2if${ffhr000}

  icnt=1
  while [ $icnt -lt 1000 ]
  do
    if [[ -s $wafs2i ]] ; then
      break
    fi

    sleep 10
    icnt=$((icnt + 1))
    if [ $icnt -ge 180 ] ;    then
        msg="ABORTING after 30 min of waiting for the gfs wafs file!"
        err_exit $msg
    fi
  done


  ########################################
  msg="HAS BEGUN!"
  postmsg "$jlogfile" "$msg"
  ########################################

  echo " ------------------------------------------"
  echo " BEGIN MAKING GFS WAFS GRIB2 0.25 DEG PRODUCTS"
  echo " ------------------------------------------"

  set +x
  echo " "
  echo "#####################################"
  echo "      Process GRIB2 WAFS 0.25 DEG PRODUCTS     "
  echo "#####################################"
  echo " "
  set -x

  opt1=' -set_grib_type same -new_grid_winds earth '
  opt21=' -new_grid_interpolation bilinear  -if '
  opt22="(:ICESEV|parm=37):"
  opt23=' -new_grid_interpolation neighbor -fi '
  opt24=' -set_bitmap 1 -set_grib_max_bits 16 '
  newgrid="latlon 0:1440:0.25 90:721:-0.25"

  ###### Step 1: Collect fields of EDPARM and ICESEV, convert to 1/4 deg for US stakeholders ######
  criteria=":EDPARM:|:ICESEV:|parm=37:"
  $WGRIB2 $wafs2 | egrep $criteria | egrep -v ":70 mb:" | $WGRIB2 -i $wafs2 -grib tmp_wafs1_grb2
  $WGRIB2 tmp_wafs1_grb2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
  $WGRIB2 -s gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 > gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx

  ###### Step 2: Collect CB fields, convert to 1/4 deg  ######
  criteria=":CBHE:|:ICAHT:"
  $WGRIB2 $wafs2 | egrep $criteria | $WGRIB2 -i $wafs2 -grib tmp_wafs2_grb2
  $WGRIB2 tmp_wafs2_grb2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid tmp_wafs_grb2.0p25

  ###### Step 3: Combine CB, EDPARM and ICESEV together for blending ######
  cat gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 >> tmp_wafs_grb2.0p25

  ###### Step 4: Change to grib2 template 5.40 and relabel pressure levels to exact numbers  ######
  # Relabelling should be removed when UPP WAFS output on the exact pressure levels
  # (after WAFS products at 1.25 deg retire)
  export pgm=wafs_grib2_0p25
  . prep_step

  startmsg
  $MPIRUN $EXECgfs/$pgm tmp_wafs_grb2.0p25 tmp_0p25_exact.grb2 >> $pgmout 2> errfile
  export err=$?; err_chk
# WGRIB2 set_lev doesn't work well. The output will fail on DEGRIB2 and
# it change values of octet 30, octet 31-34 of template 4 from 0 to undefined values
#  $WGRIB2 tmp_0p25_ref.grb2 \
#      -if ":100 mb" -set_lev "100.4 mb" -fi \
#      -if ":125 mb" -set_lev "127.7 mb" -fi \
#      -if ":150 mb" -set_lev "147.5 mb" -fi \
#      -if ":175 mb" -set_lev "178.7 mb" -fi \
#      -if ":200 mb" -set_lev "196.8 mb" -fi \
#      -if ":225 mb" -set_lev "227.3 mb" -fi \
#      -if ":275 mb" -set_lev "274.5 mb" -fi \
#      -if ":300 mb" -set_lev "300.9 mb" -fi \
#      -if ":350 mb" -set_lev "344.3 mb" -fi \
#      -if ":400 mb" -set_lev "392.7 mb" -fi \
#      -if ":450 mb" -set_lev "446.5 mb" -fi \
#      -if ":500 mb" -set_lev "506 mb" -fi \
#      -if ":600 mb" -set_lev "595.2 mb" -fi \
#      -if ":700 mb" -set_lev "696.8 mb" -fi \
#      -if ":750 mb" -set_lev "752.6 mb" -fi \
#      -if ":800 mb" -set_lev "812 mb" -fi \
#      -if ":850 mb" -set_lev "843.1 mb" -fi \
#      -grib tmp_0p25_exact.grb2

  ###### Step 5: Filter limited levels according to ICAO standard ######
  $WGRIB2 tmp_0p25_exact.grb2 | grep -F -f $FIXgfs/wafs_gfsmaster.grb2_0p25.list \
          | $WGRIB2 -i tmp_0p25_exact.grb2 -set master_table 25 -grib gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2
  $WGRIB2 -s gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2 > gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2.idx

  ###### Step 6 TOCGIB2 ######
  # As in August 2020, no WMO header is needed for WAFS data at 1/4 deg
  ## . prep_step
  ## startmsg
  ## export FORT11=gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2
  ## export FORT31=" "
  ## export FORT51=gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr}.grib2
  ## $TOCGRIB2 <  $FIXgfs/grib2_gfs_wafs_wifs_f${ffhr}.0p25 >> $pgmout 2> errfile
  ## err=$?;export err ;err_chk
  ## echo " error from tocgrib2=",$err

  if [ $SENDCOM = "YES" ] ; then

   ##############################
   # Post Files to COM
   ##############################

     mv gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr000}.grib2
     mv gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr000}.grib2.idx

     mv gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2 $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2
     mv gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2.idx $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2.idx

   #############################
   # Post Files to PCOM
   ##############################
     ## mv gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr}.grib2 $PCOM/gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr}.grib2
  fi

  ######################
  # Distribute Data
  ######################

  # Hazard WAFS data (ICESEV GTG from 100mb to 1000mb) is sent to NOMADS for US stakeholders
  if [ $SENDDBN = "YES" ] ; then
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_0P25_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr000}.grib2
  fi

  # Unblended US WAFS data is sent to NOMADS, not to WIFS, for UK to blend
  if [ $SENDDBN = "YES" ] ; then
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_0P25_UBL_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2
  fi

  if [ $FHOUT_GFS -eq 3 ] ; then
      FHINC=03
      if [ $ffhr -ge 48 ] ; then
	  FHINC=06
      fi
  else
      if [ $ffhr -lt 24 ] ; then
          FHINC=01
      elif [ $ffhr -lt 48 ] ; then
          FHINC=03
      else
          FHINC=06
      fi
  fi
  # temporarily set FHINC=03. Will remove this line for 2023 ICAO standard.
  FHINC=03
  ffhr=`expr $ffhr + $FHINC`
  if test $ffhr -lt 10
  then
      ffhr=0${ffhr}
  fi

done

################################################################################
# GOOD RUN
set +x
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
set -x
################################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"

exit 0

############## END OF SCRIPT #######################
