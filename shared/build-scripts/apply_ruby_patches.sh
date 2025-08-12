#!/bin/bash

patchdir=$1
ruby_version=$2
ruby_major_version=${ruby_version%.*}

# Verify patches
while read -r patchname; do
    patchfile="${patchdir}/${ruby_major_version}/${patchname}.patch"
    if [[ ! -f "${patchfile}" ]]; then
    echo "!! Missing mandatory patch ${patchname}"
    echo "!! Make sure ${patchfile} exists before proceeding."
    exit 1
    fi
done < "${patchdir}/mandatory_patches"

# Apply patches that apply to all Ruby major versions
if [[ -d "${patchdir}/${ruby_major_version}" ]]; then
    for i in "${patchdir}/${ruby_major_version}"/*.patch; do
    echo "$i..."
    patch -p1 -i "$i"
    done
fi

# Apply patches that apply to specific Ruby versions
if [[ -d "${patchdir}/${ruby_version}" ]]; then
    for i in "${patchdir}/${ruby_version}"/*.patch; do
    echo "$i..."
    patch -p1 -i "$i"
    done
fi
