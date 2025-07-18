# This hook checks for common issues related to void.

hook() {
	local error=0 filename= rev= libname= conflictPkg= conflictFile=
	local conflictRev= ignore= found= mapshlibs=$XBPS_COMMONDIR/shlibs
	local emptypkg=yes

	set +E

	# Check for forbidden directories that are symlinks in void.
	for f in lib bin sbin lib64 lib32 usr/sbin usr/lib64; do
		[ -e "${PKGDESTDIR}/${f}" ] || continue
		if [ "${pkgname}" = "base-files" ]; then
			if [ -L "${PKGDESTDIR}/${f}" ]; then
				continue
			fi
			msg_red "${pkgver}: /${f} must be a symlink.\n"
			error=1
		else
			msg_red "${pkgver}: /${f} must not exist.\n"
			error=1
		fi
	done

	for f in var/run usr/local usr/etc; do
		if [ -d ${PKGDESTDIR}/${f} ]; then
			msg_red "${pkgver}: /${f} directory is not allowed, remove it!\n"
			error=1
		fi
	done

	if [ -d ${PKGDESTDIR}/usr/lib/libexec ]; then
		# Add exception for kconfig,
		# other packages hard-coded path to its files
		if [ "${pkgname}" != kconfig ]; then
			msg_red "${pkgver}: /usr/lib/libexec directory is not allowed!\n"
			error=1
		fi
	fi

	for f in "$PKGDESTDIR"/*; do
		f="${f##*/}"
		case "$f" in
		'*')	# The filename is exactly '*'
			if [ -e "${PKGDESTDIR}/*" ]; then
				msg_red "${pkgver}: File /* is not allowed\n"
				error=1
			fi
			;;
		lib|bin|sbin|lib64|lib32|usr|var|opt|etc|boot|srv)
			emptypkg=no
			;;
		INSTALL|INSTALL.msg|REMOVE|REMOVE.msg|rdeps|shlib-requires|shlib-provides)
			if [ ! -f "${PKGDESTDIR}/$f" ]; then
				msg_red "${pkgver}: /${f} is not allowed\n"
				error=1
			fi
			;;
		*)
			msg_red "${pkgver}: /${f} directory is not allowed, remove it!\n"
			error=1
			;;
		esac
	done

	# Forbid empty packages unless metapackage=yes or it is 32bit devel package
	if [ "$metapackage" != yes ] && [ "$emptypkg" != no ] && [[ ${pkgname} != *-devel-32bit ]]; then
		msg_red "${pkgver}: PKGDESTDIR is empty and metapackage != yes\n"
		error=1
	fi
	if [ "$metapackage" = yes ] && [ "$emptypkg" = no ]; then
		msg_red "${pkgver}: PKGDESTDIR of meta package is not empty\n"
		error=1
	fi

	# Check that configuration files really exist.
	for f in $(expand_destdir "${conf_files}"); do
		if [ ! -f "${PKGDESTDIR}/${f}" ]; then
			msg_red "${pkgver}: '$f' configuration file not in PKGDESTDIR!\n"
			error=1
		fi
	done

	# Check for l10n files in usr/lib/locale
	if [ -d ${PKGDESTDIR}/usr/lib/locale ]; then
		local locale_allow=0 ldir
		local lroot="${PKGDESTDIR}/usr/lib/locale"

		if [ "${pkgname}" = "glibc" ]; then
			# glibc gets an exception for its included C.utf8 locale
			locale_allow=1
			for ldir in "${lroot}"/*; do
				[ "${ldir}" = "${lroot}/C.utf8" ] && continue
				locale_allow=0
			done
		fi

		if [ "${locale_allow}" -ne 1 ]; then
			msg_red "${pkgver}: /usr/lib/locale is forbidden, use /usr/share/locale!\n"
			error=1
		fi
	fi

	# Check for bash completions in etc/bash_completion.d
	# should be on usr/share/bash-completion/completions
	if [ -d ${PKGDESTDIR}/etc/bash_completion.d ]; then
		msg_red "${pkgver}: /etc/bash_completion.d is forbidden. Use /usr/share/bash-completion/completions.\n"
		error=1
	fi

	if [ -d ${PKGDESTDIR}/usr/share/zsh/vendor-functions ]; then
		msg_red "${pkgver}: /usr/share/zsh/vendor-functions is forbidden. Use /usr/share/zsh/site-functions.\n"
	fi

	if [ -d ${PKGDESTDIR}/usr/share/zsh/vendor-completions ]; then
		msg_red "${pkgver}: /usr/share/zsh/vendor-completions is forbidden. Use /usr/share/zsh/site-functions.\n"
	fi

	# Prevent packages from installing to these paths in etc, they should use
	# their equivalent in usr/lib
	for f in udev/{rules.d,hwdb.d} modprobe.d sysctl.d; do
		if [ -d ${PKGDESTDIR}/etc/${f} ]; then
			msg_red "${pkgver}: /etc/${f} is forbidden. Use /usr/lib/${f}.\n"
			error=1
		fi
	done

	# Likewise with the comment above but for usr/share
	for f in X11/xorg.conf.d gconf/schemas; do
		if [ -d ${PKGDESTDIR}/etc/${f} ]; then
			msg_red "${pkgver}: /etc/${f} is forbidden. Use /usr/share/${f}.\n"
			error=1
		fi
	done

	if [ -d ${PKGDESTDIR}/etc/dracut.conf.d ]; then
		msg_red "${pkgver}: /etc/dracut.conf.d is forbidden. Use /usr/lib/dracut/dracut.conf.d.\n"
		error=1
	fi

	if [ -d ${PKGDESTDIR}/usr/usr ]; then
		msg_red "${pkgver}: /usr/usr is forbidden, use /usr.\n"
		error=1
	fi

	if [ -d ${PKGDESTDIR}/usr/man ]; then
		msg_red "${pkgver}: /usr/man is forbidden, use /usr/share/man.\n"
		error=1
	fi

	if [[ -d ${PKGDESTDIR}/usr/share/man/man ]]; then
		msg_red "${pkgver}: /usr/share/man/man is forbidden, use /usr/share/man.\n"
		error=1
	fi

	if [ -d ${PKGDESTDIR}/usr/doc ]; then
		msg_red "${pkgver}: /usr/doc is forbidden. Use /usr/share/doc.\n"
		error=1
	fi

	if [ -d ${PKGDESTDIR}/usr/dict ]; then
		msg_red "${pkgver}: /usr/dict is forbidden. Use /usr/share/dict.\n"
		error=1
	fi

	if [ -e ${PKGDESTDIR}/usr/share/glib-2.0/schemas/gschemas.compiled ]; then
		msg_red "${pkgver}: /usr/share/glib-2.0/schemas/gschemas.compiled is forbidden. Delete it.\n"
		error=1
	fi

	# Forbid files would be generated by mimedb trigger
	for f in XMLnamespaces aliases generic-icons globs globs2 icons \
		magic mime.cache subclasses treemagic types version ; do
		if [ -f "${PKGDESTDIR}/usr/share/mime/$f" ]; then
			msg_red "${pkgver}: /usr/share/mime/$f is forbidden. Delete it.\n"
			error=1
		fi
	done

	if [ $error -gt 0 ]; then
		msg_error "${pkgver}: cannot continue with installation!\n"
	fi

	# Check for missing shlibs and SONAME bumps.
	if [ ! -s "${XBPS_STATEDIR}/${pkgname}-shlib-provides" ]; then
		return 0
	fi

	for filename in $(<"${XBPS_STATEDIR}/${pkgname}-shlib-provides"); do
		rev=${filename#*.so.}
		libname=${filename%.so*}
		_shlib=$(echo "$libname"|sed -E 's|\+|\\+|g')
		_pkgname=$(echo "$pkgname"|sed -E 's|\+|\\+|g')
		if [ "$rev" = "$filename" ]; then
			_pattern="^${_shlib}\.so[[:blank:]]+${_pkgname}-[^-]+_[0-9]+"
		else
			_pattern="^${_shlib}\.so\.[0-9]+(.*)[[:blank:]]+${_pkgname}-[^-]+_[0-9]+"
		fi
		grep -E "${_pattern}" $mapshlibs | { \
			while read -r conflictFile conflictPkg ignore; do
				found=1
				conflictRev=${conflictFile#*.so.}
				if [ -n "$ignore" -a "$ignore" != "$XBPS_TARGET_MACHINE" ]; then
					continue
				elif [ "$rev" = "$conflictRev" ]; then
					continue
				elif [[ ${rev}.* =~ $conflictRev ]]; then
					continue
				fi
				msg_red "${pkgver}: SONAME bump detected: ${libname}.so.${conflictRev} -> ${libname}.so.${rev}\n"
				msg_red "${pkgver}: please update common/shlibs with this line: \"${libname}.so.${rev} ${pkgver}\"\n"
				msg_red "${pkgver}: all reverse dependencies should also be revbumped to be rebuilt against ${libname}.so.${rev}:\n"
				_revdeps=$($XBPS_QUERY_XCMD -Rs ${libname}.so -p shlib-requires|cut -d ' ' -f1)
				for x in ${_revdeps}; do
					msg_red "   ${x%:}\n"
				done
				msg_error "${pkgver}: cannot continue with installation!\n"
			done
			# Try to match provided shlibs in virtual packages.
			for f in ${provides}; do
				_vpkgname="$($XBPS_UHELPER_CMD getpkgname ${f} 2>/dev/null)"
				_spkgname="$(grep "^${filename}" $mapshlibs | cut -d ' ' -f2)"
				_libpkgname="$($XBPS_UHELPER_CMD getpkgname ${_spkgname} 2>/dev/null)"
				if [ -z "${_spkgname}" -o  -z "${_libpkgname}" ]; then
					continue
				fi
				if [ "${_vpkgname}" = "${_libpkgname}" ]; then
					found=1
					break
				fi
			done;
			if [ -z "$found" ]; then
				_myshlib="${libname}.so"
				[ "${_myshlib}" != "${rev}" ] && _myshlib+=".${rev}"
				msg_normal "${pkgver}: ${_myshlib} not found in common/shlibs.\n"
			fi;
		}
	done
}
