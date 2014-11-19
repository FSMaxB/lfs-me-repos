#!/bin/bash

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
            echo "Automatic building of Xorg Fonts"
            echo
            echo "-h | --help    This help"
            echo "-p | --pkgman  Package manager to execute ( lfs-me )"
			echo "-c | --continue Continue from a specific package"
            exit 0
            ;;
        -p | --pkgman)
            pkgmanager="$2"
            shift 2
            ;;
		-c | --continue)
			cont="$2"
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


if [[ ! -x "$pkgmanager" ]]
then
    echo "Package manager \"${pkgmanager}\" not found!"
    exit 1
fi


for package in $(grep -v '^#' fonts.list | awk '{print $2}')
do
	#only do anything if cont isn't set or the current cont is the current package
	if [[ -z "$cont" || "$package" == "$cont" ]]; then
		cont=''
		packagedir=${package%.tar.bz2}
		#split packagedir into name and version
		packagedir=$(echo $packagedir | sed -e 's/-\([0-9]\.[0-9]\.[0-9]\)/_\1/g')    # separate name and version by '_' instead of '-'
		pkgname=$( echo "$packagedir" | awk 'BEGIN{FS="_"}{print $1}' )
		pkgver=$( echo "$packagedir" | awk 'BEGIN{FS="_"}{print $2}' )
		packagedir="${pkgname}-${pkgver}"

		# create PKGBUILD with correct pkgname and pkgver
		sed "s/packagename/${pkgname}/" fonts.proto \
			| sed "s/version_number/${pkgver}/" > "$packagedir"

		# download the source file
		"$pkgmanager" download "$packagedir"

		# create the checksum and put it in the PKGBUILD
		checksum=$( "$pkgmanager" checksums "$packagedir" | grep -E '[0-9a-f]{40}' )
		sed -i "s/checksum/${checksum}/" "$packagedir"

		#build the package
		"$pkgmanager" build "$packagedir"

		#install the package
		as_root "$pkgmanager" install "${packagedir}.pkg"
		if [[ ! $? -eq 0 ]]; then
			echo "ERROR: Non zero exit status"
			exit 1
		fi
	fi
done
