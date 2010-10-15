
dnl #
dnl # Default LZFS kernel configuration 
dnl #
AC_DEFUN([LZFS_AC_CONFIG_KERNEL], [
	LZFS_AC_KERNEL
	LZFS_AC_SPL
	LZFS_AC_ZFS
	dnl # Kernel build make options
	dnl # KERNELMAKE_PARAMS="V=1"	# Enable verbose module build
	KERNELMAKE_PARAMS="V=1"

	dnl # -Wall -fno-strict-aliasing -Wstrict-prototypes and other
	dnl # compiler options are added by the kernel build system.
	KERNELCPPFLAGS="$KERNELCPPFLAGS -DHAVE_GPL_ONLY_SYMBOLS -Wstrict-prototypes -Werror"
	KERNELCPPFLAGS="$KERNELCPPFLAGS -I$SPL -I$SPL/include"

	if test "$LINUX_OBJ" != "$LINUX"; then
		KERNELMAKE_PARAMS="$KERNELMAKE_PARAMS O=$LINUX_OBJ"
	fi

	AC_SUBST(KERNELMAKE_PARAMS)
	AC_SUBST(KERNELCPPFLAGS)
])


dnl #
dnl # Detect name used for Module.symvers file in kernel
dnl #
AC_DEFUN([LZFS_AC_MODULE_SYMVERS], [
	modpost=$LINUX/scripts/Makefile.modpost
	AC_MSG_CHECKING([kernel file name for module symbols])
	if test -f "$modpost"; then
		if grep -q Modules.symvers $modpost; then
			LINUX_SYMBOLS=Modules.symvers
		else
			LINUX_SYMBOLS=Module.symvers
		fi
	else
		LINUX_SYMBOLS=NONE
	fi
	AC_MSG_RESULT($LINUX_SYMBOLS)
	AC_SUBST(LINUX_SYMBOLS)
])

dnl #
dnl # Detect the kernel to be built against
dnl #
AC_DEFUN([LZFS_AC_KERNEL], [
	AC_ARG_WITH([linux],
		AS_HELP_STRING([--with-linux=PATH],
		[Path to kernel source]),
		[kernelsrc="$withval"])

	AC_ARG_WITH(linux-obj,
		AS_HELP_STRING([--with-linux-obj=PATH],
		[Path to kernel build objects]),
		[kernelbuild="$withval"])

	AC_MSG_CHECKING([kernel source directory])
	if test -z "$kernelsrc"; then
		headersdir="/lib/modules/$(uname -r)/build"
		if test -e "$headersdir"; then
			sourcelink=$(readlink -f "$headersdir")
		else
			sourcelink=$(ls -1d /usr/src/kernels/* \
				     /usr/src/linux-* \
			             2>/dev/null | grep -v obj | tail -1)
		fi

		if test -n "$sourcelink" && test -e ${sourcelink}; then
			kernelsrc=`readlink -f ${sourcelink}`
		else
			AC_MSG_RESULT([Not found])
			AC_MSG_ERROR([
	*** Please make sure the kernel devel package for your distribution
	*** is installed then try again.  If that fails you can specify the
	*** location of the kernel source with the '--with-linux=PATH' option.])
		fi
	else
		if test "$kernelsrc" = "NONE"; then
			kernsrcver=NONE
		fi
	fi

	AC_MSG_RESULT([$kernelsrc])
	AC_MSG_CHECKING([kernel build directory])
	if test -z "$kernelbuild"; then
		if test -d ${kernelsrc}-obj/${target_cpu}/${target_cpu}; then
			kernelbuild=${kernelsrc}-obj/${target_cpu}/${target_cpu}
		elif test -d ${kernelsrc}-obj/${target_cpu}/default; then
		        kernelbuild=${kernelsrc}-obj/${target_cpu}/default
		elif test -d `dirname ${kernelsrc}`/build-${target_cpu}; then
			kernelbuild=`dirname ${kernelsrc}`/build-${target_cpu}
		else
			kernelbuild=${kernelsrc}
		fi
	fi
	AC_MSG_RESULT([$kernelbuild])

	AC_MSG_CHECKING([kernel source version])
	utsrelease1=$kernelbuild/include/linux/version.h
	utsrelease2=$kernelbuild/include/linux/utsrelease.h
	utsrelease3=$kernelbuild/include/generated/utsrelease.h
	if test -r $utsrelease1 && fgrep -q UTS_RELEASE $utsrelease1; then
		utsrelease=linux/version.h
	elif test -r $utsrelease2 && fgrep -q UTS_RELEASE $utsrelease2; then
		utsrelease=linux/utsrelease.h
	elif test -r $utsrelease3 && fgrep -q UTS_RELEASE $utsrelease3; then
		utsrelease=generated/utsrelease.h
	fi

	if test "$utsrelease"; then
		kernsrcver=`(echo "#include <$utsrelease>";
		             echo "kernsrcver=UTS_RELEASE") |
		             cpp -I $kernelbuild/include |
		             grep "^kernsrcver=" | cut -d \" -f 2`

		if test -z "$kernsrcver"; then
			AC_MSG_RESULT([Not found])
			AC_MSG_ERROR([*** Cannot determine kernel version.])
		fi
	else
		AC_MSG_RESULT([Not found])
		AC_MSG_ERROR([*** Cannot find UTS_RELEASE definition.])
	fi

	AC_MSG_RESULT([$kernsrcver])

	LINUX=${kernelsrc}
	LINUX_OBJ=${kernelbuild}
	LINUX_VERSION=${kernsrcver}

	AC_SUBST(LINUX)
	AC_SUBST(LINUX_OBJ)
	AC_SUBST(LINUX_VERSION)

	LZFS_AC_MODULE_SYMVERS
])


dnl #
dnl # Detect name used for the additional SPL Module.symvers file.  If one
dnl # does not exist this is likely because the SPL has been configured
dnl # but not built.  To allow recursive builds a good guess is made as to
dnl # what this file will be named based on what it is named in the kernel
dnl # build products.  This file will first be used at link time so if
dnl # the guess is wrong the build will fail then.  This unfortunately
dnl # means the ZFS package does not contain a reliable mechanism to
dnl # detect symbols exported by the SPL at configure time.
dnl #
AC_DEFUN([LZFS_AC_SPL_MODULE_SYMVERS], [
	AC_MSG_CHECKING([spl file name for module symbols])
	if test -r $SPL_OBJ/Module.symvers; then
		SPL_SYMBOLS=Module.symvers
	elif test -r $SPL_OBJ/Modules.symvers; then
		SPL_SYMBOLS=Modules.symvers
	elif test -r $SPL_OBJ/module/Module.symvers; then
		SPL_SYMBOLS=Module.symvers
	elif test -r $SPL_OBJ/module/Modules.symvers; then
		SPL_SYMBOLS=Modules.symvers
	else
		SPL_SYMBOLS=$LINUX_SYMBOLS
	fi

	AC_MSG_RESULT([$SPL_SYMBOLS])
	AC_SUBST(SPL_SYMBOLS)
])

dnl #
dnl # Detect the SPL module to be built against
dnl #
AC_DEFUN([LZFS_AC_SPL], [
	AC_ARG_WITH([spl],
		AS_HELP_STRING([--with-spl=PATH],
		[Path to spl source]),
		[splsrc="$withval"])

	AC_ARG_WITH([spl-obj],
		AS_HELP_STRING([--with-spl-obj=PATH],
		[Path to spl build objects]),
		[splbuild="$withval"])


	AC_MSG_CHECKING([spl source directory])
	if test -z "$splsrc"; then
		sourcelink=`ls -1d /usr/src/spl-*/${LINUX_VERSION} \
		            2>/dev/null | tail -1`

		if test -z "$sourcelink" || test ! -e $sourcelink; then
			sourcelink=../spl
		fi

		if test -e $sourcelink; then
			splsrc=`readlink -f ${sourcelink}`
		else
			AC_MSG_RESULT([Not found])
			AC_MSG_ERROR([
	*** Please make sure the spl devel package for your distribution
	*** is installed then try again.  If that fails you can specify the
	*** location of the spl source with the '--with-spl=PATH' option.])
		fi
	else
		if test "$splsrc" = "NONE"; then
			splbuild=NONE
			splsrcver=NONE
		fi
	fi

	AC_MSG_RESULT([$splsrc])
	AC_MSG_CHECKING([spl build directory])
	if test -z "$splbuild"; then
		splbuild=${splsrc}
	fi
	AC_MSG_RESULT([$splbuild])

	AC_MSG_CHECKING([spl source version])
	if test -r $splbuild/spl_config.h &&
		fgrep -q SPL_META_VERSION $splbuild/spl_config.h; then

		splsrcver=`(echo "#include <spl_config.h>";
		            echo "splsrcver=SPL_META_VERSION") |
		            cpp -I $splbuild |
		            grep "^splsrcver=" | cut -d \" -f 2`
	fi

	if test -z "$splsrcver"; then
		AC_MSG_RESULT([Not found])
		AC_MSG_ERROR([
		*** Cannot determine the version of the spl source.
		*** Please prepare the spl source before running this script])
	fi

	AC_MSG_RESULT([$splsrcver])

	SPL=${splsrc}
	SPL_OBJ=${splbuild}
	SPL_VERSION=${splsrcver}

	AC_SUBST(SPL)
	AC_SUBST(SPL_OBJ)
	AC_SUBST(SPL_VERSION)

	LZFS_AC_SPL_MODULE_SYMVERS
])

dnl #
dnl # Detect name used for the additional ZFS Module.symvers file.  If one
dnl # does not exist this is likely because the ZFS has been configured
dnl # but not built.  To allow recursive builds a good guess is made as to
dnl # what this file will be named based on what it is named in the kernel
dnl # build products.  This file will first be used at link time so if
dnl # the guess is wrong the build will fail then.  This unfortunately
dnl # means the LZFS package does not contain a reliable mechanism to
dnl # detect symbols exported by the ZFS at configure time.
dnl #
AC_DEFUN([LZFS_AC_ZFS_MODULE_SYMVERS], [
	AC_MSG_CHECKING([zfs file name for module symbols])
	if test -r $ZFS_OBJ/Module.symvers; then
		ZFS_SYMBOLS=Module.symvers
	elif test -r $ZFS_OBJ/Modules.symvers; then
		ZFS_SYMBOLS=Modules.symvers
	elif test -r $ZFS_OBJ/module/Module.symvers; then
		ZFS_SYMBOLS=Module.symvers
	elif test -r $ZFS_OBJ/module/Modules.symvers; then
		ZFS_SYMBOLS=Modules.symvers
	else
		ZFS_SYMBOLS=$LINUX_SYMBOLS
	fi

	AC_MSG_RESULT([$ZFS_SYMBOLS])
	AC_SUBST(ZFS_SYMBOLS)
])

dnl #
dnl # Detect the ZFS module to be built against
dnl #
AC_DEFUN([LZFS_AC_ZFS], [
	AC_ARG_WITH([zfs],
		AS_HELP_STRING([--with-zfs=PATH],
		[Path to zfs source]),
		[zfssrc="$withval"])

	AC_ARG_WITH([zfs-obj],
		AS_HELP_STRING([--with-zfs-obj=PATH],
		[Path to zfs build objects]),
		[zfsbuild="$withval"])


	AC_MSG_CHECKING([zfs source directory])
	if test -z "$zfssrc"; then
		sourcelink=`ls -1d /usr/src/zfs-*/${LINUX_VERSION} \
		            2>/dev/null | tail -1`

		if test -z "$sourcelink" || test ! -e $sourcelink; then
			sourcelink=../zfs
		fi

		if test -e $sourcelink; then
			zfssrc=`readlink -f ${sourcelink}`
		else
			AC_MSG_RESULT([Not found])
			AC_MSG_ERROR([
	*** Please make sure the zfs devel package for your distribution
	*** is installed then try again.  If that fails you can specify the
	*** location of the zfs source with the '--with-zfs=PATH' option.])
		fi
	else
		if test "$zfssrc" = "NONE"; then
			zfsbuild=NONE
			zfssrcver=NONE
		fi
	fi

	AC_MSG_RESULT([$zfssrc])
	AC_MSG_CHECKING([zfs build directory])
	if test -z "$zfsbuild"; then
		zfsbuild=${zfssrc}
	fi
	AC_MSG_RESULT([$zfsbuild])

	AC_MSG_CHECKING([zfs source version])
	if test -r $zfsbuild/zfs_config.h &&
		fgrep -q ZFS_META_VERSION $zfsbuild/zfs_config.h; then

		zfssrcver=`(echo "#include <zfs_config.h>";
		            echo "zfssrcver=ZFS_META_VERSION") |
		            cpp -I $zfsbuild |
		            grep "^zfssrcver=" | cut -d \" -f 2`
	fi

	if test -z "$zfssrcver"; then
		AC_MSG_RESULT([Not found])
		AC_MSG_ERROR([
		*** Cannot determine the version of the zfs source.
		*** Please prepare the zfs source before running this script])
	fi

	AC_MSG_RESULT([$zfssrcver])

	ZFS=${zfssrc}
	ZFS_OBJ=${zfsbuild}
	ZFS_VERSION=${zfssrcver}

	AC_SUBST(ZFS)
	AC_SUBST(ZFS_OBJ)
	AC_SUBST(ZFS_VERSION)

	LZFS_AC_ZFS_MODULE_SYMVERS
])
dnl #
dnl # Check for rpm+rpmbuild to build RPM packages.  If these tools
dnl # are missing it is non-fatal but you will not be able to build
dnl # RPM packages and will be warned if you try too.
dnl #
AC_DEFUN([LZFS_AC_RPM], [
	RPM=rpm
	RPMBUILD=rpmbuild

	AC_MSG_CHECKING([whether $RPM is available])
	AS_IF([tmp=$($RPM --version 2>/dev/null)], [
		RPM_VERSION=$(echo $tmp | $AWK '/RPM/ { print $[3] }')
		HAVE_RPM=yes
		AC_MSG_RESULT([$HAVE_RPM ($RPM_VERSION)])
	],[
		HAVE_RPM=no
		AC_MSG_RESULT([$HAVE_RPM])
	])

	AC_MSG_CHECKING([whether $RPMBUILD is available])
	AS_IF([tmp=$($RPMBUILD --version 2>/dev/null)], [
		RPMBUILD_VERSION=$(echo $tmp | $AWK '/RPM/ { print $[3] }')
		HAVE_RPMBUILD=yes
		AC_MSG_RESULT([$HAVE_RPMBUILD ($RPMBUILD_VERSION)])
	],[
		HAVE_RPMBUILD=no
		AC_MSG_RESULT([$HAVE_RPMBUILD])
	])

	AC_SUBST(HAVE_RPM)
	AC_SUBST(RPM)
	AC_SUBST(RPM_VERSION)

	AC_SUBST(HAVE_RPMBUILD)
	AC_SUBST(RPMBUILD)
	AC_SUBST(RPMBUILD_VERSION)
])

dnl #
dnl # Check for dpkg+dpkg-buildpackage to build DEB packages.  If these
dnl # tools are missing it is non-fatal but you will not be able to build
dnl # DEB packages and will be warned if you try too.
dnl #
AC_DEFUN([LZFS_AC_DPKG], [
	DPKG=dpkg
	DPKGBUILD=dpkg-buildpackage

	AC_MSG_CHECKING([whether $DPKG is available])
	AS_IF([tmp=$($DPKG --version 2>/dev/null)], [
		DPKG_VERSION=$(echo $tmp | $AWK '/Debian/ { print $[7] }')
		HAVE_DPKG=yes
		AC_MSG_RESULT([$HAVE_DPKG ($DPKG_VERSION)])
	],[
		HAVE_DPKG=no
		AC_MSG_RESULT([$HAVE_DPKG])
	])

	AC_MSG_CHECKING([whether $DPKGBUILD is available])
	AS_IF([tmp=$($DPKGBUILD --version 2>/dev/null)], [
		DPKGBUILD_VERSION=$(echo $tmp | \
		    $AWK '/Debian/ { print $[4] }' | cut -f-4 -d'.')
		HAVE_DPKGBUILD=yes
		AC_MSG_RESULT([$HAVE_DPKGBUILD ($DPKGBUILD_VERSION)])
	],[
		HAVE_DPKGBUILD=no
		AC_MSG_RESULT([$HAVE_DPKGBUILD])
	])

	AC_SUBST(HAVE_DPKG)
	AC_SUBST(DPKG)
	AC_SUBST(DPKG_VERSION)

	AC_SUBST(HAVE_DPKGBUILD)
	AC_SUBST(DPKGBUILD)
	AC_SUBST(DPKGBUILD_VERSION)
])

dnl #
dnl # Until native packaging for various different packing systems
dnl # can be added the least we can do is attempt to use alien to
dnl # convert the RPM packages to the needed package type.  This is
dnl # a hack but so far it has worked reasonable well.
dnl #
AC_DEFUN([LZFS_AC_ALIEN], [
	ALIEN=alien

	AC_MSG_CHECKING([whether $ALIEN is available])
	AS_IF([tmp=$($ALIEN --version 2>/dev/null)], [
		ALIEN_VERSION=$(echo $tmp | $AWK '{ print $[3] }')
		HAVE_ALIEN=yes
		AC_MSG_RESULT([$HAVE_ALIEN ($ALIEN_VERSION)])
	],[
		HAVE_ALIEN=no
		AC_MSG_RESULT([$HAVE_ALIEN])
	])

	AC_SUBST(HAVE_ALIEN)
	AC_SUBST(ALIEN)
	AC_SUBST(ALIEN_VERSION)
])

dnl #
dnl # Using the VENDOR tag from config.guess set the default
dnl # package type for 'make pkg': (rpm | deb | tgz)
dnl #
AC_DEFUN([LZFS_AC_DEFAULT_PACKAGE], [
	VENDOR=$(echo $ac_build_alias | cut -f2 -d'-')

	AC_MSG_CHECKING([default package type])
	case "$VENDOR" in
		fedora)     DEFAULT_PACKAGE=rpm ;;
		redhat)     DEFAULT_PACKAGE=rpm ;;
		sles)       DEFAULT_PACKAGE=rpm ;;
		ubuntu)     DEFAULT_PACKAGE=deb ;;
		debian)     DEFAULT_PACKAGE=deb ;;
		slackware)  DEFAULT_PACKAGE=tgz ;;
		*)          DEFAULT_PACKAGE=rpm ;;
	esac

	AC_MSG_RESULT([$DEFAULT_PACKAGE])
	AC_SUBST(DEFAULT_PACKAGE)
])

dnl #
dnl # Default ZFS package configuration
dnl #
AC_DEFUN([LZFS_AC_PACKAGE], [
	LZFS_AC_RPM
	LZFS_AC_DPKG
	LZFS_AC_ALIEN
	LZFS_AC_DEFAULT_PACKAGE
])
