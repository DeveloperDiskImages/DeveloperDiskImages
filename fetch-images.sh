#!/bin/sh

LEGACY_DEVELOPER_DISK_IMAGES_PATH="/Applications/Xcode.app/Contents/Developer/Platforms"
PERSONALIZED_DEVELOPER_DISK_IMAGES_PATH="/Library/Developer/DeveloperDiskImages"

LEGACY_TARGET_DIR="./LegacyImages" 
PERSONALIZED_TARGET_DIR="./PersonalizedImages" 

cd "$(dirname "$0")"

if [ ! -e "$LEGACY_TARGET_DIR" ]; then
mkdir "$LEGACY_TARGET_DIR"
fi

if [ ! -e "$PERSONALIZED_TARGET_DIR" ]; then
mkdir "$PERSONALIZED_TARGET_DIR"
fi

echo '--------------------------------------------------'
echo 'Fetch All Xcode Developer Disk Images'
echo '--------------------------------------------------'

echo 'Legacy Images:'
find "$LEGACY_DEVELOPER_DISK_IMAGES_PATH" -type d -name "DeviceSupport" | while read -r devicesupport_dir; do
    # Compute the relative path from SRC to the DeviceSupport dir's parent
    parent_dir=$(dirname "$devicesupport_dir")
    rel_parent="${parent_dir#$LEGACY_DEVELOPER_DISK_IMAGES_PATH/}"
    
    # For all files and dirs in this DeviceSupport dir, copy if not present in target
    find "$devicesupport_dir" -type f | while read -r file; do
        rel_path="${file#$LEGACY_DEVELOPER_DISK_IMAGES_PATH/}" # Remove source dir from path
        dest_file="$LEGACY_TARGET_DIR/$rel_path"
        dest_dir=$(dirname "$dest_file")
        if [ ! -e "$dest_file" ]; then
            mkdir -p "$dest_dir"
            cp "$file" "$dest_file"
            echo "Copied: $rel_path"
        else
            echo "Skipped: $rel_path"
        fi
    done
done

echo '--------------------------------------------------'

echo 'Personalized Images:'
find "$PERSONALIZED_TARGET_DIR" -type f -name "*.plist" -print -delete
find "$PERSONALIZED_DEVELOPER_DISK_IMAGES_PATH" -type f | while read -r file; do
    rel_path="${file#$PERSONALIZED_DEVELOPER_DISK_IMAGES_PATH/}" # Remove source dir from path
    dest_file="$PERSONALIZED_TARGET_DIR/$rel_path"
    dest_dir=$(dirname "$dest_file")
    if [ ! -e "$dest_file" ]; then
        mkdir -p "$dest_dir"
        cp "$file" "$dest_file"
        echo "Copied: $rel_path"
    else
        echo "Skipped: $rel_path"
    fi
done

echo '--------------------------------------------------'

echo 'Done!'

rm -r -f $TMP_DIR