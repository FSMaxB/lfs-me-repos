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


for package in $(grep -v '^#' xorg-libraries.list | awk '{print $2}')
do
  packagedir=${package%.tar.bz2}
  #split packagedir into name and version
  pkgname=$( echo "$packagedir" | awk 'BEGIN{FS="-"}{print $1}' )
  pkgver=$( echo "$packagedir" | awk 'BEGIN{FS="-"}{print $2}' )

  # create PKGBUILD with correct pkgname and pkgver
  sed "s/packagename/${pkgname}/" xorg-libraries.proto \
      | sed "s/version/${pkgver}/" > "$packagedir"

  case "$packagedir" in
    libFS-[0-9]* )
        sed -e 's!./configure $XORG_CONFIG!sed -e '\''/#include <X11/ i\\#include <X11\\/Xtrans\\/Xtransint.h>'\'' -e '\''s/_FSTransReadv(svr->trans_conn/readv(svr->trans_conn->fd/'\'' -i src/FSlibInt.c; ./configure $XORG_CONFIG!' -i "$packagedir"
        ;;
    libXfont-[0-9]* )
        sed -e 's!./configure $XORG_CONFIG!./configure $XORG_CONFIG --disable-devel-docs!' -i "$packagedir"
        ;;
    libXft-[0-9]* )
        sed -e 's!.tar.bz2" )!.tar.bz2" "http://www.linuxfromscratch.org/patches/blfs/7.5/libXft-2.3.1-freetype_fix-1.patch" )!' -i "$packagedir"
        sed -e 's!./configure $XORG_CONFIG!patch -Np1 -i "${sources_dir}/libXft-2.3.1-freetype_fix-1.patch"; ./configure $XORG_CONFIG!' -i "$packagedir"
        ;;
    libXt-[0-9]* )
        sed -e 's!./configure $XORG_CONFIG!./configure $XORG_CONFIG --with-appdefaultdir=/etc/X11/app-defaults!' -i "$packagedir"
        ;;
  esac

  # download the source file
  "$pkgmanager" download "$packagedir" -s "$sources_dir" --ignore-checksums

  # create the checksum and put it in the PKGBUILD
  if [ $packagedir == libXft-2.3.1 ]
  then
      #get 2 checksums for libXft
      checksum=$( "$pkgmanager" checksums "$packagedir" -s "$sources_dir" | tail -n 3 | head -n 2 )
      checksum=${checksum/$'\n'/ }
  else
      checksum=$( "$pkgmanager" checksums "$packagedir" -s "$sources_dir" | tail -n 2 | head -n 1 )
  fi
  sed -i "s/checksum/${checksum}/" "$packagedir"

  #build the package
  "$pkgmanager" build "$packagedir" -s "$sources_dir"

  #install the package
  as_root "$pkgmanager" install "${packagedir}.pkg"
done
