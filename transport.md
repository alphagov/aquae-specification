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

4. TODO doesn't cover how the messaging protocol is sat on top. Any other conditions e.g. disconnecting?
