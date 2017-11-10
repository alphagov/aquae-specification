.PHONY: all dist clean mrproper

PROTOS=metadata.proto messaging.proto transport.proto
EXAMPLES=examples/bluebadge.federation examples/bluebadge.federation.txt
ALL=$(PROTOS) $(EXAMPLES)
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

examples/%.federation.txt: examples/%
	cd $(dir $@) && ./$(notdir $<) > $(notdir $@)

examples/%.federation: examples/%.federation.txt
	./tools/amc $< > $@

%.proto : %.md
	./md2protobuf $< $@

specification-%.tar: $(ALL)
	$(TAR) $@ $+ examples/*.key

%.tgz: %.tar
	$(GZ) $@ $+
