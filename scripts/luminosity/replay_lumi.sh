#!/bin/bash

# Flags for plotting yield or reanalyzing all data
while getopts 'ht' flag; do
    case "${flag}" in
	h)
	    echo "The following flags can be called for the luminosity analysis..."
	    echo "    -h, help"
	    echo "    -t, reproduce trigger windows"
	    echo "        RUNNUMBER=arg1, MAXEVENTS=arg2"
	    exit 0 ;;
	t) t_flag='true' ;;
	*) print_usage
	exit 1 ;;
    esac
done


if [[ $t_flag = "true" ]]; then
    echo
    echo "Starting Luminosity Script"
    echo "I take as arguments the Run Number and max number of events!"
    RUNNUMBER=$2
    MAXEVENTS=$3
    #MAXEVENTS=12500

    if [[ $2 -eq "" ]]; then
	echo "I need a Run Number!"
	exit 2
    fi

    if [[ $3 -eq "" ]]; then
	echo "Only Run Number entered...I'll assume -1 events!" 
	MAXEVENTS=-1 
    fi
else
    echo
    echo "Starting Luminosity Script"
    echo "I take as arguments the Run Number and max number of events!"
    RUNNUMBER=$1
    MAXEVENTS=$2
    #MAXEVENTS=12500

    if [[ $1 -eq "" ]]; then
	echo "I need a Run Number!"
	exit 2
    fi

    if [[ $2 -eq "" ]]; then
	echo "Only Run Number entered...I'll assume -1 events!" 
	MAXEVENTS=-1 
    fi
fi

# Runs script in the ltsep python package that grabs current path enviroment
if [[ ${HOSTNAME} = *"cdaq"* ]]; then
    PATHFILE_INFO=$(python3 /home/cdaq/pionLT-2021/hallc_replay_lt/UTIL_PION/bin/python/ltsep_pionlt/scripts/getPathDict.py "$PWD")
else
    PATHFILE_INFO=$(python3 /group/c-pionlt/USERS/${USER}/replay_lt_env/lib/python3.9/site-packages/ltsep/scripts/getPathDict.py "$PWD")
fi

# Split the string we get to individual variables, easier for printing and use later
VOLATILEPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f1` # Cut the string on , delimitter, select field (f) 1, set variable to output of command
ANALYSISPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f2`
HCANAPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f3`
HCANAPATH="/u/group/c-pionlt/hcana_08_10_24_Root6_24_08_Alma9_HodoEffUpdate"
REPLAYPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f4`
UTILPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f5`
PACKAGEPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f6`
OUTPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f7`
ROOTPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f8`
REPORTPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f9`
CUTPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f10`
PARAMPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f11`
SCRIPTPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f12`
ANATYPE=`echo ${PATHFILE_INFO} | cut -d ','  -f13`
LTUSER=`echo ${PATHFILE_INFO} | cut -d ','  -f14`
HOST=`echo ${PATHFILE_INFO} | cut -d ','  -f15`

# Source stuff depending upon hostname. Change or add more as needed  
if [[ "${HOST}" = *"farm"* ]]; then
    if [[ "${HOST}" != *"ifarm"* ]]; then
        echo "Using ROOT/module setup from wrapper script"
    fi
    cd "$HCANAPATH"
    source "$HCANAPATH/setup.sh"
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh"
elif [[ "${HOST}" = *"qcd"* ]]; then
    source "$REPLAYPATH/setup.sh" 
fi

cd "$REPLAYPATH"

###################################################################################################################################################
echo "Running scaler replay / BCM calibration for ${RUNNUMBER}..."

rm -f "$REPLAYPATH/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_${MAXEVENTS}.root"
rm -f "$REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"

eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/SCALERS/replay_coin_scalers.C($RUNNUMBER,${MAXEVENTS})\""

cd "$REPLAYPATH/CALIBRATION/bcm_current_map"

root -b -l<<EOF 
.L ScalerCalib.C
.x run.C("${REPLAYPATH}/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_${MAXEVENTS}.root")
.q  
EOF

mv bcmcurrent_${RUNNUMBER}.param "$REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"
echo "moving output: mv bcmcurrent_${RUNNUMBER}.param $REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"

cd "$REPLAYPATH"

sleep 3

rm -f "$REPLAYPATH/ROOTfiles/Analysis/Lumi/${ANATYPE}LT_replay_luminosity_${RUNNUMBER}_${MAXEVENTS}.root"

echo "Running full lumi replay for ${RUNNUMBER} ${MAXEVENTS} (overwrite mode)..."

eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/PRODUCTION/PionLT_REPLAY/FullReplay_PionLT_LumiTest.C($RUNNUMBER,$MAXEVENTS)\"" | tee "$REPLAYPATH/REPORT_OUTPUT/Analysis/Lumi/${ANATYPE}LT_replay_luminosity_${RUNNUMBER}_${MAXEVENTS}.report"

sleep 3

if [[ $t_flag = "true" ]]; then
    # Sets trigger windows
    echo
    echo "Running trigWindows.sh ${RUNNUMBER}..."
    echo
    cd ${UTILPATH}/scripts/trig_windows/src/
    #source trigWindows.sh ${RUNNUMBER}
    python3 trigcuts.py Lumi ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}
    echo
    echo "Plotting trigWindows for ${RUNNUMBER}..."
    echo
    cd ${UTILPATH}/scripts/trig_windows/src
    #source trigWindows.sh -p ${RUNNUMBER}
    python3 plot_trig.py Lumi ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}
fi

# Analyzes lumi runs
echo
echo "Running lumiyield.py ${RUNNUMBER} ${MAXEVENTS}..."
cd ${UTILPATH}/scripts/luminosity/src/
python3 lumiyield.py ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}
