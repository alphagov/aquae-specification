.PHONY: all dist clean mrproper

ALL=metadata.proto messaging.proto transport.proto
SPEC=specification-$(shell git describe --always --tags).tgz

all: $(ALL)

dist: $(SPEC)

clean:
	rm -f $(ALL)
	rm -f $(SPEC)

mrproper: clean
	rm -f *~
	rm -f specification-*.tgz


%.proto : %.md
	./md2protobuf $< $@

specification-%.tgz: $(ALL)
	tar -zcvf $@ $+

