README
======

## Introduction

The scripts in this directory create Aquae Metadata files in Protobuf Text Format that describes an Aquae
Federation.

These are synthetic examples for testing and may not represent real world entities or usage.

## Dependencies

Besides builtin GNU coreutils, this script requires:

* `openssl >= 1.0`

### Mac OS X users

You will need GNU coreutils (`date` compliance) and openssl (Mac OS X's builtin version is  too old)

```bash
$ brew install coreutils openssl
```

Note that coreutils prefixes commands with `g` to avoid clashes with builtin commands. A possible workaround is to edit `create-validity` and replace:

```bash
date --date=@$@ -u '+%Y-%m-%dT%H:%M:%SZ'
```

by

```bash
gdate --date=@$@ -u '+%Y-%m-%dT%H:%M:%SZ'
```

## Running

For example, to get an example federation that illustrates our Blue Badge Parking Permit, run:

```bash
$ ./bluebadge > bluebadge.proto
```

Convert it to binary with the Aquae Metadata Compiler thus:

```bash
$ ../tools/amc bluebadge.proto > bluebadge.proto.bin
```

The above will create several certificates and associated keys in the current directory.
You can remove then with

```bash
$ make clean
```
