#!/bin/bash

sources_dir=""
pkgmanager=""


as_root()
{
    if [ $EUID = 0 ]        
    then
        $*
    elif [ -x /usr/bin/sudo ]
    then 
        PATH="$PATH:/sbin:/usr/sbin" sudo $*
    else
        su -c \\"$*\\"
    fi
}

#Parse Arguments
while :
do
    case "$1" in
        -h | --help)
            echo "Automatic building of Xorg Protocol Headers"
            echo
            echo "-h | --help    This help"
            echo "-s | --sources Source file directory"
            echo "-p | --pkgman  Package manager to execute ( lfs-me )"
            exit 0
            ;;
        -s | --sources)
            sources_dir="$2"
            shift 2
            ;;
        -p | --pkgman)
            pkgmanager="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option \"$1\""
            exit 1
            ;;
        *)
            break
            ;;
    esac
done


if [ ! -d "$sources_dir" ]
then
    echo "Sources dir \"${sources_dir}\" not found!"
    exit 1
fi

if [ ! -x "$pkgmanager" ]
then
    echo "Package manager \"${pkgmanager}\" not found!"
    exit 1
fi


for package in $(grep -v '^#' xorg-fonts.list | awk '{print $2}')
do
  packagedir=${package%.tar.bz2}
  #split packagedir into name and version
  packagedir=$(echo $packagedir | sed -e 's/-\([0-9]\.[0-9]\.[0-9]\)/_\1/g')    # separate name and version by '_' instead of '-'
  pkgname=$( echo "$packagedir" | awk 'BEGIN{FS="_"}{print $1}' )
  pkgver=$( echo "$packagedir" | awk 'BEGIN{FS="_"}{print $2}' )
  packagedir="${pkgname}-${pkgver}"

  # create PKGBUILD with correct pkgname and pkgver
  sed "s/packagename/${pkgname}/" xorg-fonts.proto \
      | sed "s/version/${pkgver}/" > "$packagedir"

  # download the source file
  "$pkgmanager" download "$packagedir" -s "$sources_dir" --ignore-checksums

  # create the checksum and put it in the PKGBUILD
  checksum=$( "$pkgmanager" checksums "$packagedir" -s "$sources_dir" | tail -n 2 | head -n 1 )
  sed -i "s/checksum/${checksum}/" "$packagedir"

  #build the package
  "$pkgmanager" build "$packagedir" -s "$sources_dir"

  #install the package
  as_root "$pkgmanager" install "${packagedir}.pkg"
done
