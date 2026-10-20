#!/bin/sh

LEGACY_DEVELOPER_DISK_IMAGES_PATH="/Applications/Xcode.app/Contents/Developer/Platforms"
PERSONALIZED_DEVELOPER_DISK_IMAGES_PATH="/Library/Developer/DeveloperDiskImages"

LEGACY_TARGET_DIR="./LegacyImages" 
PERSONALIZED_TARGET_DIR="./PersonalizedImages" 
CRYPTEX_TARGET_DIR="./CryptexImages"

cd "$(dirname "$0")"

if [ ! -e "$LEGACY_TARGET_DIR" ]; then
mkdir "$LEGACY_TARGET_DIR"
fi

if [ ! -e "$PERSONALIZED_TARGET_DIR" ]; then
mkdir "$PERSONALIZED_TARGET_DIR"
fi

if [ ! -e "$CRYPTEX_TARGET_DIR" ]; then
mkdir "$CRYPTEX_TARGET_DIR"
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

# The Cryptex1 variant (installed through cryptexd rather than the image mounter) ships inside the
# personalized images. Extract it per platform under fixed names, with a BuildManifest.plist that
# only holds the cryptex identities and declares those same names.
echo 'Cryptex Images:'
CRYPTEX_PAYLOADS="Cryptex1,GenericDmg:Image.dmg Cryptex1,GenericTrustCache:Image.dmg.trustcache Cryptex1,CryptexInfoPlist:Image.dmg.cryptex_info Cryptex1,GenericVolume:Image.dmg.root_hash"
find "$PERSONALIZED_DEVELOPER_DISK_IMAGES_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r ddi_dir; do
    ddi_name=$(basename "$ddi_dir")
    dest_dir="$CRYPTEX_TARGET_DIR/$ddi_name"
    dest_manifest="$dest_dir/BuildManifest.plist"
    rm -r -f "$dest_dir"
    mkdir -p "$dest_dir"
    cp "$ddi_dir/Restore/BuildManifest.plist" "$dest_manifest"

    # Drop every non-cryptex identity, walking backwards so the remaining indices stay valid
    i=$(plutil -extract BuildIdentities raw "$dest_manifest")
    while [ "$i" -gt 0 ]; do
        i=$((i - 1))
        if ! plutil -extract "BuildIdentities.$i.Manifest.Cryptex1,GenericDmg" raw "$dest_manifest" >/dev/null 2>&1; then
            plutil -remove "BuildIdentities.$i" "$dest_manifest"
        fi
    done
    count=$(plutil -extract BuildIdentities raw "$dest_manifest")
    if [ "$count" -eq 0 ]; then
        rm -r -f "$dest_dir"
        echo "Skipped: $ddi_name (no cryptex identity)"
        continue
    fi

    for payload in $CRYPTEX_PAYLOADS; do
        key="${payload%%:*}"
        file="${payload#*:}"
        src_path=""
        i=0
        while [ "$i" -lt "$count" ]; do
            path=$(plutil -extract "BuildIdentities.$i.Manifest.$key.Info.Path" raw "$dest_manifest")
            if [ -z "$src_path" ]; then
                src_path="$path"
                cp "$ddi_dir/Restore/$src_path" "$dest_dir/$file"
                echo "Copied: $ddi_name/$file ($src_path)"
            elif [ "$path" != "$src_path" ]; then
                echo "Warning: $ddi_name cryptex identities disagree on $key ($src_path vs $path)"
            fi
            plutil -replace "BuildIdentities.$i.Manifest.$key.Info.Path" -string "$file" "$dest_manifest"
            i=$((i + 1))
        done
    done
    cp "$ddi_dir/version.plist" "$dest_dir/version.plist"
    plutil -convert xml1 "$dest_manifest"
    echo "Wrote: $ddi_name/BuildManifest.plist ($count identities)"
done

echo '--------------------------------------------------'

echo 'Done!'

rm -r -f $TMP_DIR