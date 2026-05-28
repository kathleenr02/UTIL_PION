#!/bin/bash

# Flags for plotting yield or reanalyzing all data
while getopts 'ht' flag; do
    case "${flag}" in
	h)
	    echo "The following flags can be called for the luminosity analysis..."
	    echo "    -h, help"
	    echo "    -t, reproduce trigger windows"
	    echo "        RUNLIST=arg1, MAXEVENTS=arg2"
	    exit 0 ;;
	t) t_flag='true' ;;
	*) print_usage
	exit 1 ;;
    esac
done

shift $((OPTIND-1))

echo
echo "Starting Luminosity Script"
echo "I take as arguments the Run List path and max number of events!"

RUNLIST=$1
MAXEVENTS=$2

if [[ -z "$RUNLIST" ]]; then
    echo "I need a run list path!"
    exit 2
fi

if [[ ! -f "$RUNLIST" ]]; then
    echo "Run list not found: $RUNLIST"
    exit 2
fi

if [[ -z "$MAXEVENTS" ]]; then
    echo "Only run list entered...I'll assume -1 events!"
    MAXEVENTS=-1
fi

# Runs script in the ltsep python package that grabs current path enviroment
if [[ ${HOSTNAME} = *"cdaq"* ]]; then
    PATHFILE_INFO=`python3 /home/cdaq/pionLT-2021/hallc_replay_lt/UTIL_PION/bin/python/ltsep_pionlt/scripts/getPathDict.py $PWD`
elif [[ "${HOSTNAME}" = *"farm"* ]]; then
    PATHFILE_INFO=`python3 /u/group/c-pionlt/USERS/${USER}/replay_lt_env/lib/python3.9/site-packages/ltsep/scripts/getPathDict.py $PWD`
fi

VOLATILEPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f1`
ANALYSISPATH=`echo ${PATHFILE_INFO} | cut -d ','  -f2`
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
USER=`echo ${PATHFILE_INFO} | cut -d ','  -f14`
HOST=`echo ${PATHFILE_INFO} | cut -d ','  -f15`

# Source stuff depending upon hostname
if [[ "${HOST}" = *"farm"* ]]; then
    if [[ "${HOST}" != *"ifarm"* ]]; then
	source /site/12gev_phys/softenv.sh 2.3
	source /apps/root/6.18.04/setroot_CUE.bash
    fi
    cd "$HCANAPATH"
    source "$HCANAPATH/setup.sh"
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh"
elif [[ "${HOST}" = *"qcd"* ]]; then
    source "$REPLAYPATH/setup.sh"
fi

cd "$REPLAYPATH"

while read -r RUNNUMBER; do

    # Skip blank lines and comments
    [[ -z "$RUNNUMBER" ]] && continue
    [[ "$RUNNUMBER" =~ ^# ]] && continue

    echo
    echo "######################################################################"
    echo "Processing run ${RUNNUMBER} with MAXEVENTS=${MAXEVENTS}"
    echo "######################################################################"
    echo

    # Run scaler replay
    SCALER_FILE="$REPLAYPATH/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_${MAXEVENTS}.root"

    if [[ -f "$SCALER_FILE" ]]; then
	echo "Scaler replayfile already exists: $SCALER_FILE"
	echo "Skipping scaler replay and BCM calibration."
    else
	# Remove old BCM current param only if regenerating scalers
	rm -f "$REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"

	# Run scaler replay
	eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/SCALERS/replay_coin_scalers.C($RUNNUMBER,${MAXEVENTS})\""

	cd "$REPLAYPATH/CALIBRATION/bcm_current_map"

	root -b -l<<EOF
.L ScalerCalib.C
.x run.C("${SCALER_FILE}")
.q
EOF

	mv -f bcmcurrent_${RUNNUMBER}.param \
	"$REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"

	echo "moving output: mv bcmcurrent_${RUNNUMBER}.param $REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_${RUNNUMBER}.param"

	cd "$REPLAYPATH"
    fi

    sleep 3

    # Remove old lumi replay outputs
    rm -f "$REPLAYPATH/ROOTfiles/Analysis/Lumi/${ANATYPE}LT_replay_luminosity_${RUNNUMBER}_${MAXEVENTS}.root"

    if [[ "${HOSTNAME}" != *"ifarm"* ]]; then

	if [[ "${HOSTNAME}" == *"cdaq"* ]]; then

	    eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/PRODUCTION/PionLT_REPLAY/FullReplay_PionLT_LumiTest_Coin.C($RUNNUMBER,$MAXEVENTS)\"" \
	    | tee "$REPLAYPATH/REPORT_OUTPUT/Analysis/Lumi/${ANATYPE}LT_output_coin_production_Summary_${RUNNUMBER}_${MAXEVENTS}.report"

	else

	    eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/PRODUCTION/PionLT_REPLAY/FullReplay_PionLT_LumiTest_Coin.C($RUNNUMBER,$MAXEVENTS)\""

	fi

    elif [[ "${HOSTNAME}" == *"ifarm"* ]]; then

	eval "$REPLAYPATH/hcana -l -q -b \"SCRIPTS/COIN/PRODUCTION/PionLT_REPLAY/FullReplay_PionLT_LumiTest_Coin.C($RUNNUMBER,$MAXEVENTS)\"" \
	| tee "$REPLAYPATH/REPORT_OUTPUT/Analysis/Lumi/${ANATYPE}LT_output_coin_production_Summary_${RUNNUMBER}_${MAXEVENTS}.report"

    fi

    sleep 3

    if [[ $t_flag = "true" ]]; then

	echo
	echo "Running trigWindows.sh ${RUNNUMBER}..."
	echo

	cd ${UTILPATH}/scripts/trig_windows/src/

	python3 trigcuts.py Lumi ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}

	echo
	echo "Plotting trigWindows for ${RUNNUMBER}..."
	echo

	cd ${UTILPATH}/scripts/trig_windows/src

	python3 plot_trig.py Lumi ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}

    fi

    echo
    echo "Running lumiyield.py ${RUNNUMBER} ${MAXEVENTS}..."

    cd ${UTILPATH}/scripts/luminosity/src/

    python3 lumiyield.py ${ANATYPE}LT_replay_luminosity ${RUNNUMBER} ${MAXEVENTS}

    cd "$REPLAYPATH"

done < "$RUNLIST"