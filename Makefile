.PHONY: all clean mrproper

ALL=metadata.proto messaging.proto transport.proto

all: $(ALL)

clean:
	rm -f $(ALL)

mrproper: clean
	rm -f *~


%.proto : %.md
	./md2protobuf $< $@

