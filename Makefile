BUILDTYPE ?= Debug
DESTDIR ?=
# this Makefile is generated by make via configure outside of gyp
# we do this because gyp sucks
include base/pkg/out/include.mk

VIRGO_BASE_DIR = base
ifndef PRODUCTION
SIGNING_KEY=${VIRGO_BASE_DIR}/tests/ca/server.key.insecure
else
SIGNING_KEY=/home/buildslave/server.key
endif

%.zip.sig: $(zip_files)
	cd ${VIRGO_BASE_DIR} && python tools/build.py sig-gen ${SIGNING_KEY} $(patsubst %.zip.sig, %.zip, $@) out/${BUILDTYPE}/$@

all: out/Makefile
	$(MAKE) -C out BUILDTYPE=$(BUILDTYPE) -j4
	mv out/${BUILDTYPE}/virgo out/${BUILDTYPE}/${PKG_NAME}
	python ${VIRGO_BASE_DIR}/tools/build.py sig-gen ${SIGNING_KEY} out/${BUILDTYPE}/${PKG_NAME} out/${BUILDTYPE}/${PKG_NAME}.sig

out/Makefile:
	./configure

distclean:
	rm -rf pkg/out

clean: distclean
	# TODO: we should probably not kill out/include.mk if no_gen_platform_gypi exists
	rm -rf out

pep8:
	python ${VIRGO_BASE_DIR}/tools/pep8.py --exclude=deps,gyp,contrib,pep8.py --ignore=E126,E501,E128,E127 . configure

test: tests
tests: all
	python ${VIRGO_BASE_DIR}/tools/build.py test
	$(MAKE) pep8

crash: all
	python ${VIRGO_BASE_DIR}/tools/build.py crash

install: all
	install -d ${BINDIR}
	install -d ${ETCDIR}
	install -d ${SHAREDIR}
	install out/${BUILDTYPE}/${PKG_NAME} ${BINDIR}/${PKG_NAME}
	install out/${BUILDTYPE}/${BUNDLE_NAME}-bundle.zip ${SHAREDIR}/
#	install out/${BUILDTYPE}/bundle-test.zip ${SHAREDIR}

dist:
	# -ln -fs out/${BUILDTYPE}/${PKG_NAME} ${PKG_NAME}
	${VIRGO_BASE_DIR}/tools/git-archive-all/git-archive-all --prefix=${TARNAME}/ out/${TARNAME}.tar.gz
	tar xzf out/${TARNAME}.tar.gz -C out
	cp -f ${VIRGO_BASE_DIR}/platform.gypi out/${TARNAME}/${VIRGO_BASE_DIR}
	touch out/${TARNAME}/${VIRGO_BASE_DIR}/no_gen_platform_gypi
	# TODO really, the above statement should be enough (ie, this should be done by configure)
	cp ${VIRGO_BASE_DIR}/pkg/out/include.mk out/${TARNAME}
	make -C ${VIRGO_BASE_DIR}/deps/luvit dist_build
	mv  ${VIRGO_BASE_DIR}/deps/luvit/luvit.gyp.dist out/${TARNAME}/base/deps/luvit/luvit.gyp
	cp -f ${VIRGO_BASE_DIR}/lib/virgo_exports.c out/${TARNAME}/base/lib/virgo_exports.c
	cd out && tar -cf ${TARNAME}.tar ${TARNAME}
	gzip -f -9 out/${TARNAME}.tar > out/${TARNAME}.tar.gz


#######################
### RPM

rpmbuild_dir = out/rpmbuild
rpmbuild_dirs = $(rpmbuild_dir)/SPECS \
                $(rpmbuild_dir)/SOURCES \
                $(rpmbuild_dir)/RPMS \
                $(rpmbuild_dir)/BUILD \
                $(rpmbuild_dir)/SRPMS

$(rpmbuild_dirs):
	mkdir -p $@

rpm: all dist $(rpmbuild_dirs)
#	cp out/${TARNAME}.tar.gz $(rpmbuild_dir)/SOURCES/
#	mv out/${TARNAME} $(rpmbuild_dir)/BUILD/
	rsync -a --exclude='out' ${BUNDLE_DIR} $(rpmbuild_dir)/BUILD/
	mv out/${TARNAME}.tar.gz $(rpmbuild_dir)/SOURCES/
	cp ${VIRGO_BASE_DIR}/pkg/out/${PKG_NAME}.spec $(rpmbuild_dir)/SPECS/
	rpmbuild --define '_topdir $(PWD)/$(rpmbuild_dir)' -ba $(rpmbuild_dir)/SPECS/${PKG_NAME}.spec

rpm-sign:
	-mv ~/.rpmmacros ~/.rpmmacros.bak
	ln -s $(PWD)/base/pkg/rpm/rpm_macros_gpg ~/.rpmmacros
	find $(rpmbuild_dir)/ -type f -name *.rpm -exec base/pkg/rpm/rpm-sign.exp {} \;
	rm ~/.rpmmacros
	-mv ~/.rpmmacros.bak ~/.rpmmacros

#######################
### Debian
export NAME := ${SHORT_DESCRIPTION} Package Repo (${DOCUMENTATION_LINK})
export EMAIL := ${EMAIL}
echo:
	echo "$(NAME)"
	echo "$(EMAIL)"

debbuild_dir = out/debbuild

$(debbuild_dir):
	mkdir -p $@

deb: all dist $(debbuild_dir)
	cp out/${TARNAME}.tar.gz $(debbuild_dir)
	rm -rf $(debbuild_dir)/${TARNAME} && mkdir $(debbuild_dir)/${TARNAME}
	tar zxf out/${TARNAME}.tar.gz --strip-components=1 -C $(debbuild_dir)/${TARNAME}
	mkdir $(debbuild_dir)/${TARNAME}/debian
	cp -rf ${VIRGO_BASE_DIR}/pkg/out/* $(debbuild_dir)/${TARNAME}/debian
	mkdir $(debbuild_dir)/${TARNAME}/base/pkg/out/
	cp ${VIRGO_BASE_DIR}/pkg/out/include.mk $(debbuild_dir)/${TARNAME}/base/pkg/out/
	# cp -rf ${BUNDLE_DIR} $(debbuild_dir)
	cd $(debbuild_dir)/${TARNAME} && dch -v ${PKG_FULL_VERSION} 'Release of ${VERSION}'
	cd $(debbuild_dir)/${TARNAME} && dpkg-buildpackage

deb-sign:
	@echo noop

PKG_TYPE=$(shell python ${VIRGO_BASE_DIR}/tools/pkgutils.py)
pkg:
	python ${VIRGO_BASE_DIR}/tools/version.py > out/VERSION
	[ "$(PKG_TYPE)" = "None" ] || $(MAKE) $(PKG_TYPE)

pkg-sign:
	[ "$(PKG_TYPE)" = "None" ] || make $(PKG_TYPE)-sign

update:
	git submodule foreach git fetch && git submodule update --init --recursive


.PHONY: clean dist distclean all test tests endpoint-tests rpm $(spec_file_built) deb pkg rpm-sign pkg-sign
