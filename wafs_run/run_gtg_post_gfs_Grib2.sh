#!/bin/bash

#BSUB -L /bin/sh
#BSUB -oo /ptmpp1/Yali.Mao/out.gtg.post.gfs.Grib2
#BSUB -eo /ptmpp1/Yali.Mao/err.gtg.post.gfs.Grib2
#BSUB -n 16
#BSUB -J post_gtg
#BSUB -W 00:29
#BSUB -q "debug"
#BSUB -R span[ptile=2]
#BSUB -R affinity[core(2):distribute=balance]
#BSUB -P GFS-T2O
#BSUB -x
#BSUB -a poe


export NWROOT=/nwprod
export COMROOT=/com2
export PCOMROOT=/pcom
export NWROOTp1=/nwprod
export DCOMROOT=/dcom
export util_ver=v1.0.0
export NWROOTprod=/nwprod2
export g2tmpl_ver=v1.3.0

set -x
export OMP_NUM_THREADS=1
export MP_TASK_AFFINITY=core:$OMP_NUM_THREADS
export MP_EUILIB=us
export MP_MPILIB=mpich2
export OMP_STACKSIZE=1G
export MP_STDOUTMODE=unordered
export MP_LABELIO=yes
export MP_TASK_AFFINITY=core
export FOR_DISABLE_STACK_TRACE=true
export decfort_dump_flag=y

set -x


. /usrx/local/Modules/default/init/bash
module load prod_util/v1.0.2
module load grib_util/v1.0.1

module load ibmpe ics lsf
export MP_COMPILER=intel
export MP_LABELIO=yes

export PDY=20161021
export cyc=00
export cycle=t${cyc}z

# specify your running and output directory
export user=`whoami`
export DATA=/ptmpp1/${user}/gtg.working.$PDY

# this script mimics operational GFS post processing production
export MP_LABELIO=yes

rm -rf $DATA; mkdir -p $DATA
cd $DATA
export COMOUT=/ptmpp1/${user}/gtg.$PDY
mkdir -p $COMOUT

export HOMEglobal=/nwprod2/global_shared.v13.0.1
export HOMEgfs=/global/save/Yali.Mao/project/post_branch
#export post_ver=${post_ver:-v5.0.0}
export crtm_ver=${crtm_ver:-v2.0.6}
export gsm_ver=${gsm_ver:-v12.0.0}
export util_ver=v1.0.0

#export post_times="06 09 12 15 18 21 24 27 30 33 36"
#export post_times=" 12 18"
export post_times=" 21"

export PostFlatFile=$HOMEgfs/parm/postxconfig-NT-GFS.txt
export POSTGPEXEC=$HOMEgfs/exec/ncep_post

ksh $HOMEgfs/jobs/JGFS_NCEPPOST