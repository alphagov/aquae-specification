.PHONY: all dist clean mrproper

ALL=metadata.proto messaging.proto transport.proto
SPEC=specification-$(shell git describe --always --tags).tgz

ifndef TAR
TAR=tar -cvf
endif
ifndef GZ
GZ=gzip -c >
endif

all: $(ALL)

dist: $(SPEC)

clean:
	$(RM) $(ALL)
	$(RM) $(SPEC)

mrproper: clean
	$(RM) *~
	$(RM) specification-*.tgz


%.proto : %.md
	./md2protobuf $< $@

specification-%.tar: $(ALL)
	$(TAR) $@ $+

%.tgz: %.tar
	$(GZ) $@ $+
