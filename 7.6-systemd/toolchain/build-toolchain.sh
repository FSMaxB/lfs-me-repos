#!/bin/sh

#check if run as root
[ $UID -eq 0 ] && echo "Don't run this script as root!" && exit 1

#help output
if [ "$1" == "-h" ]
then
	echo "Script to build the LFS 7.6-systemd toolchain."
	echo "Usage:"
	echo -e "\t$0 [package]"
	echo -e "\tpackage: First package in list to get installed. This is to be able to continue where you left of before."
	exit 0
fi

[ -z $LFS ] && echo "LFS environment variable isn't set." && exit 1
[ -z $LFS_TGT ] && echo "LFS_TGT environment variable isn't set." && exit 1

[ "$(readlink -f /tools)" != "$(readlink -f "${LFS}/tools")" ] && echo "'/tools' has to be a symlink to '${LFS}/tools'" && exit 1
[ -z $1 ] && [ ! -z "$(ls /tools)" ] && echo "'/tools' has to be empty!" && exit 1

#load settings from ~/.lfs-me
[ -f ~/.lfs-me ] && source ~/.lfs-me

#check settings from ~/.lfs-me
[ "$(readlink -f "$log_dir")" != "$(readlink -f "${LFS}/tools/var/log/lfs-me")" ] && echo "log_dir is set to the wrong directory '$log_dir', it should be '${LFS}/tools/var/log/lfs-me'" && exit 1
[ "$(readlink -f "$index_dir")" != "$(readlink -f "${LFS}/tools/var/lfs-me/index")" ] && echo "index_dir is set to the wrong directory '$index_dir', it should be '${LFS}/tools/var/lfs-me/index'" && exit 1

#set settings
log_dir="${LFS}/tools/var/log/lfs-me"
index_dir="${LFS}/tools/var/lfs-me/index"

export LFS LFS_TGT log_dir index_dir

install=(
	'binutils-pass1-2.24'
	'gcc-pass1-4.9.1'
	'linux-headers-3.16.5'
	'glibc-2.20'
	'libstdc++-4.9.1'
	'binutils-pass2-2.24'
	'gcc-pass2-4.9.1'
	'zlib-1.2.8'
	'tcl-8.6.2'
	'expect-5.45'
	'dejagnu-1.5.1'
	'check-0.9.14'
	'ncurses-5.9'
	'bash-4.3-7'
	'bzip2-1.0.6'
	'coreutils-8.23'
	'diffutils-3.3'
	'file-5.19'
	'findutils-4.4.2'
	'gawk-4.1.1'
	'gettext-0.19.2'
	'grep-2.20'
	'gzip-1.6'
	'm4-1.4.17'
	'make-4.0'
	'patch-2.7.1'
	'perl-5.20.0'
	'sed-4.2.2'
	'tar-1.28'
	'texinfo-5.2'
	'util-linux-2.25.1'
	'xz-5.0.5'
	'fakeroot-1.18.4'
	'nano-2.3.6'
	'rsync-3.1.1'
	'openssl-1.0.1j'
	'wget-1.15'
	'libevent-2.0.21'
	'tmux-1.9a'
	'vim-7.4'
	'curl-7.37.1'
	'git-2.1.0'
	'lfs-me-3.0.2'
)

mkdir -v pkg

[ -f build-toolchain.log ] && rm build-toolchain.log
touch build-toolchain.log

for package in "${install[@]}"
do
	if [ -z $1 ] || [ $1 == $package ]
	then
		shift "$#" #remove commandline parameters
		echo "BUILDING ${package}"
		lfs-me build "$package" --no-cert-check | tee -a build-toolchain.log
		[ ! ${PIPESTATUS[0]} -eq 0 ] && echo "Building '$package' failed!" && exit 1
		mv "${package}.pkg" pkg/
		lfs-me install "pkg/${package}.pkg" | tee -a build-toolchain.log
		[ ! ${PIPESTATUS[0]} -eq 0 ] && echo "Installing '$package' failed!" && exit 1
	fi
done
