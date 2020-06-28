#!/bin/bash

#pip3 install -U youtube-dl
source /app/youtube-archive.conf

echo "### Youtube Archive Vars ###"
echo "Channels File:   ${CHANNELS_FILE}"
echo "Archive File:    ${ARCHIVE_FILE}"
echo "Save Archive:    ${SAVE_ARCHIVE}"
echo "Quality:         ${QUALITY}"
echo "Rate Limit:      ${RATE_LIMIT}"
echo "Retries:         ${RETRIES}"
echo "Buffer Size:     ${BUFFER_SIZE}"
echo "Video Uid:       ${VIDEO_UID}"
echo "Video Gid:       ${VIDEO_GID}"
echo "Output Format:   ${OUTPUT_FORMAT}"
echo "Download Format: ${format}"
echo "### End Youtube Archive Vars ###"

echo "Starting youtube-archive..."
pushd /youtube-directory

echo "Backing up ${ARCHIVE_FILE}..."

if [[ -f "${ARCHIVE_FILE}" && "${SAVE_ARCHIVE}" -eq 1 ]]; then
	last_archive="$(date -I'seconds')-${ARCHIVE_FILE}"
	mkdir -p "${ARCHIVE_FILE%.*}-history"

	cp "${ARCHIVE_FILE}" "${ARCHIVE_FILE%.*}-history/${last_archive}"

	pushd "${ARCHIVE_FILE%.*}-history/"
	zip old-archive-files.zip $(readlink last-archive-file)
	rm -f $(readlink last-archive-file)
	ln -sf "${last_archive}" last-archive-file
	popd
fi

youtube-dl \
	--format "${format}" \
	--limit-rate "${RATE_LIMIT}" \
	--buffer-size "${BUFFER_SIZE}" \
	--retries "${RETRIES}" \
	--newline \
	--ignore-errors \
	--no-continue \
	--no-overwrites \
	--geo-bypass \
	--add-metadata \
	--all-subs \
	--embed-subs \
	--write-thumbnail \
	--restrict-filenames \
	--merge-output-format "mkv" \
	--output "${OUTPUT_FORMAT}" \
	--download-archive "${ARCHIVE_FILE}" \
	--batch-file "${CHANNELS_FILE}" 

# Find all newly downloaded files
while IFS=  read -r -d $'\0'; do
	array+=("$REPLY")
done < <(find . -not -name "*.txt" -iname "*.mkv" -type f -user 0 -group 0 -print0)

# Print out newly downloaded files
ARRAY_LEN=${#array[@]}
if [ "${ARRAY_LEN}" -eq 0 ]; then
	echo "No New Videos Downloaded..."
	exit 0
else
	echo "### Newly Downloaded Videos ###"
	for i in "${array[@]}"; do
	       echo "$i" | sed 's#\./##g' | sed 's#/#: #g' | sed 's/\.mkv//'
	done
	echo "### End Newly Downloaded Videos ###"
fi

merge() {
	filename="$1"
	sequence_num="$2"
	video_name="$(echo $1 | sed 's#\./##g' | sed 's#/#: #g' | sed 's/\.mkv//')"
	if [ -f "${filename/.mkv/.jpg}" ]; then
		if [ $(magick identify -format %m "${filename/.mkv/.jpg}") == "WEBP" ]; then
			mv "${filename/.mkv/.jpg}" "${filename/.mkv/.webp}"
			magick convert "${filename/.mkv/.webp}" "${filename/.mkv/.jpg}"
		fi
	elif [ -f "${filename/.mkv/.webp}" ]; then
		if [ $(magick identify -format %m "${filename/.mkv/.webp}") == "WEBP" ]; then
			magick convert "${filename/.mkv/.webp}" "${filename/.mkv/.jpg}"
		else
			mv "${filename/.mkv/.webp}" "${filename/.mkv/.jpg}"
		fi
	fi


        echo "Adding thumbnail: (${sequence_num}/${ARRAY_LEN}) ${video_name}"
 	ffmpeg -v warning -i "${filename}" -i "${filename/.mkv/.jpg}" -map 1 -map 0 \
		-c copy -disposition:0 attached_pic \
		-f matroska "${filename}.tempfile" && \
		mv -f "${filename}.tempfile" "${filename}" && \
		chown "${VIDEO_UID}":"${VIDEO_GID}" "${filename}" && \
		rm -f "${filename/.mkv/.jpg}" "${filename/.mkv/.webp}"
}

export -f merge
export ARRAY_LEN VIDEO_UID VIDEO_GID SHELL=$(type -p bash) 

# Merge thumbnail into mkv
echo "### Start Post-Processing ###"
parallel -k merge "{}" "{#}" ::: "${array[@]}"
echo "### End Post-Processing ###"

