#!/bin/bash
# Converts the recorded clips of the "FREE FPS SFX Pack" (Can, 2026-10-04; zip in
# private_assets/ or wherever it was extracted) into assets/audio: mono (3D sounds need it),
# 44.1 kHz 16-bit, leading/trailing silence cut, long tails trimmed with a fade.
#   bash tools/convert_sfx_pack.sh PATH/TO/EXTRACTED/PACK
set -e
SRC="$1"
DST="$(cd "$(dirname "$0")/.." && pwd)/assets/audio"
conv() { # source name, output name, optional max seconds
	local extra=""
	if [ -n "$3" ]; then
		extra=",atrim=0:$3,afade=t=out:st=$(python3 -c "print(max(0, $3 - 0.4))"):d=0.4"
	fi
	ffmpeg -v error -y -i "$SRC/$1" -ac 1 -ar 44100 -sample_fmt s16 \
		-af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse$extra" \
		"$DST/$2.wav"
}
for i in 1 2 3 4 5 6 7 8; do conv "Footstep_Boot_Concrete-00$i.wav" "step_$i"; done
# Landing: two footsteps 18 ms apart (both feet).
ffmpeg -v error -y -i "$SRC/Footstep_Boot_Concrete-011.wav" -i "$SRC/Footstep_Boot_Concrete-014.wav" \
	-filter_complex "[0]silenceremove=start_periods=1:start_threshold=-50dB[a];[1]silenceremove=start_periods=1:start_threshold=-50dB,adelay=18|18[b];[a][b]amix=inputs=2:normalize=0,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse" \
	-ac 1 -ar 44100 -sample_fmt s16 "$DST/land.wav"
for i in 1 2 3 4; do
	conv "Shotgun_Shot-00$i.wav" "shot_shotgun_$i"
	conv "Sniper_Shot-00$i.wav" "shot_heavy_$i" 1.8
	conv "Rocket_Shot-00$i.wav" "shot_launcher_$i"
	conv "Rocket_Explosion-00$i.wav" "explosion_$i"
done
conv "Shotgun_Pump.wav" shotgun_pump
conv "Sniper_Scope .wav" scope_in
conv "GrapplingHook_Shot-001.wav" grapple_shot
conv "GrapplingHook_Hook-001.wav" grapple_hook
conv "Player_Warning.wav" warning
