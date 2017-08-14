# Transport Protocol

1. Aquae nodes will establish connections over TCP.

    1. Nodes will accept connections on TCP on the port advertised in the metadata file. 

2. All connections to the TCP port must use TLS.

    1. All TLS connections MUST only use the algorithms and cipher suites permitted by the TLS v1.3 specification.
    TODO: is TLS v1.3 all authenticated encyption (e.g. MACed, so GCM, AEAD)
    2. Nodes SHOULD use TLS v1.3 where available, but MAY use TLS v1.2, as long as the above requirement is obeyed.

3. Both nodes on the TLS connection MUST supply certificates to the other party (mutual TLS).

    1. The submitted certificate MUST match the node's entry in the metadata file. TODO: does this allow virtual hosting, where we host multiple query servers from the same port? Do we want to do that?
    2. If a node submits a certificate that is not in the metadata file entry for that node, the connection MUST be dropped immediately.

4. Each Aquae query between a pair of nodes requires its own TCP connection between the nodes. If this becomes a problem we will address it in a future revision of the Transport Protocol.

## Encapsulation Protocol

The [Messaging Protocol](./messaging.md) is composed of messages specified using Google's Protocol Buffers. The Transport Protocol needs to know which message to expect and how much data to read so we encapsulate the [Messaging Protocol](./messaging.md) with this Encapsulation Protocol.

1. The Encapsulation Protocol is represented using a Protocol Buffer structure.

    ```protobuf
    syntax = "proto2";
    package Aquae.Transport;
    option java_package           = "uk.gov.Aquae.ProtocolBuffers";
    option java_outer_classname   = "Transport";
    option java_multiple_files    = false;
    option java_string_check_utf8 = true;
    option java_generic_services  = false;
    ```
2. The Encapsulation Protocol consists of a Header describing the Length and
   Type of the [Messaging Protocol](./messaging.md) message that follows.

   ```protobuf
   message Header {
	   enum Type {
		   IDENTITY_SIGN_REQUEST = 1;
		   // FIXME: Where is the response to IDENTITY_SIGN_REQUEST?
		   SIGNED_QUERY          = 2;
		   BAD_QUERY_RESPONSE    = 3;
		   QUERY_RESPONSE        = 4;
		   SECOND_WHISTLE        = 5;
		   QUERY_ANSWER          = 6;
		   FINISH                = 7;
	   }

	   optional int32  length = 1;
	   optional Type   type   = 2;
   }
   ```
3. The Header message must not ever be more than 255 bytes long.

4. Implementations *MUST* support encapsulated messages up to 1MiB (1024 * 1024 octets) long. That is to say, if a Header message contains a length field < (1024 * 1024) and the frame obeys this protocol, then the implementation *MUST* be able to read and process the entire frame.


## Framing Protocol

The [Encapsulation Protocol](#Encapsulation_Protocol) is composed of messages specified using Google's Protocol Buffers. These are not self describing or self delimiting. Therefore, when we want to transmit them over the wire, we frame them using the protocol outlined in this section. The Framing Protocol tells the reader what version of the protocol we are speaking and gives them enough information to read the Header message of the [Encapsulation Protocol](#Encapsulation_Protocol). The Framing Protocol is not self synchronising and relies on the proper operation of the [Encapsulation Protocol](#Encapsulation_Protocol) in order to find the beginning of the next Frame.

1. Each Frame consists of a Version Number, a Length and a Payload. The Version Number and Length are as small as possible and we do not currently worry about the alignment of the Payload. We expect the receiver to read the Version Number and the Length before reading the Payload and therefore take care of realigning the Payload itself. If this becomes a problem we will address it in a future revision of the Framing Protocol.

        +-----------------------------------------------------------------------+
        |0       |1       |2       |3       |4       |5       |6       |7
        |01234567|01234567|01234567|01234567|01234567|01234567|01234567|01234567|
        +-----------------------------------------------------------------------+
        |VERSION | LENGTH | PAYLOAD...                                          |
        +-----------------------------------------------------------------------+
        | ...PAYLOAD...                                                         |
        |                                                                       |
        |                                                                       |
        +-----------------------------------------------------------------------+

2. The Version number comes first and is a 4 bit integer followed by 4 reserved bits. The version number must always be zero in this version of the Framing Protocol. The reserved bits must always be zero in this version of the Framing Protocol.

3. The length comes next and is an 8 bit integer. The length describes the number of 8 bit octets that follow containing the entirety of the [Encapsulation Protocol](#Encapsulation_Protocol)'s Header message and nothing more.

4. A number of opaque 8 bit octets, at least as large in number as the previously specified Length, then follows. This is the Payload. There is no maximum length of a Payload and it may be longer than the number of octets specified by the Length header if the [Encapsulation Protocol](#Encapsulation_Protocol) Header message specifies its own payload.

5. After the end of the Payload, another Frame begins immediately.

6. Frames continue, back-to-back until a higher level protocol decides to close the connection.

### Rules of the Grammar

The TCP is represented by any stream satisfying the `stream` rule.

    stream:
      frame
      frame stream

    frame:
      version reserved length payload

    version:
      (nibble)

    reserved:
      (nibble)

    length:
      (char)

    payload:
      (octet)[length] (octet)[]

