.PRECIOUS: %.key %.crt
.PHONY:    all clean mrproper %.crt.info


all: example.key example.crt example.key.pk8.der example.crt.der

clean:
	find -name \*.csr -o -name \*.key.pk8.der -o -name \*.crt.der -type f | xargs -r rm

mrproper: clean
	find -name \*.key -o -name \*.crt -type f | xargs -r rm
	rm -f *~


## Key & Certificate Creation Rules
%.key:
	openssl genpkey -out $@ -outform PEM -algorithm rsa -pkeyopt rsa_keygen_bits:4096

%.csr: %.key
	openssl req -outform PEM -out $@ -new -subj "/CN=$*" -key $< -keyform PEM -sha256 -batch -verbose

%.crt: %.csr %.key
	openssl x509 -inform PEM -outform PEM -in $*.csr -out $@ -sha256 -addtrust clientAuth -addtrust serverAuth -signkey $*.key -clrext -keyform PEM -days 365 -req

## Phony Certificate Visualiser Rule
%.crt.info: %.crt
	openssl x509 -in $< -noout -text


## Key & Certificate Conversion Rules

# Java Requires the keys & certificates in these formats
%.key.pk8.der: %.key
	openssl pkcs8 -topk8 -inform PEM -outform DER -in $< -out $@ -nocrypt

%.crt.der: %.crt
	openssl x509 -inform PEM -outform DER -in $< -out $@

