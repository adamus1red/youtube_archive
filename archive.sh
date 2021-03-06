#!/bin/bash

python3 -m pip install -U youtube-dlc
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

	pushd "${ARCHIVE_FILE%.*}-history/"
	zip old-archive-files.zip "$(readlink last-archive-file)"
	rm -f ./*"${ARCHIVE_FILE}"
	ln -sf "${last_archive}" last-archive-file
	popd

	cp "${ARCHIVE_FILE}" "${ARCHIVE_FILE%.*}-history/${last_archive}"

fi

youtube-dlc \
	--format "${format}" \
	--limit-rate "${RATE_LIMIT}" \
	--buffer-size "${BUFFER_SIZE}" \
	--retries "${RETRIES}" \
	--ignore-errors \
	--newline \
	--no-continue \
	--no-overwrites \
	--geo-bypass \
	--add-metadata \
	--all-subs \
	--embed-subs \
	--embed-thumbnail \
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
else
	echo "### Newly Downloaded Videos ###"
	for i in "${array[@]}"; do
	       echo "$i" | sed 's#\./##g' | sed 's#/#: #g' | sed 's/\.mkv//'
	       chown "${VIDEO_GID}":"${VIDEO_UID}" "$i"
	done
	echo "### End Newly Downloaded Videos ###"
fi

