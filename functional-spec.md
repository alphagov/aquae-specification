# Functional Specification v0.1

## Transport Protocol

1. PDE nodes will establish connections over TCP.

    1. Nodes will accept connections on TCP on the port advertised in the metadata file. 

2. All connections to the TCP port must use TLS.
    
    1. All TLS connections MUST only use the algorithms and cipher suites permitted by the TLS v1.3 specification.
    TODO: is TLS v1.3 all authenticated encyption (e.g. MACed, so GCM, AEAD)
    2. Nodes SHOULD use TLS v1.3 where available, but MAY use TLS v1.2, as long as the above requirement is obeyed.

3. Both nodes on the TLS connection MUST supply certificates to the other party (mutual TLS).

    1. The submitted certificate MUST match the node's entry in the metadata file. TODO: does this allow virtual hosting, where we host multiple query servers from the same port? Do we want to do that?
    2. The submitted certificate MUST be signed by a trust authority that both nodes trust. TODO: we're trying to _avoid_ doing this. So don't do it.
    3. If a node submits a certificate that is not in the metadata file entry for that node, the connection MUST be dropped immediately.

4. TODO doesn't cover how the messaging protocol is sat on top. Any other conditions e.g. disconnecting?

## Messaging Protocol

### Querying

0. When a node wishes to make a query, it looks up the query in the metadata file and examines the available `Choices` for the query. TODO: who looks at the meteadata? Is it the first node "within PDE" or is it another client library that is not in the metadata? E.g. there is a random webserver not part of the network communicating with a trusted PDE node, who looks at the metadata here?

    1. The node should, where possible, expose these choices to the user. 

1. When a node has decided from the available `Choices`, it creates a query plan using the metadata file according to the following algorithm. 

    0. Start with a empty set of nodes which require the subject's identity (the "identity set").
    1. The node looks up which node can directly answer the question it wants answered (the "answering node").

        1. If multiple nodes can answer the query, the node should load balance it's requests between all the nodes in the set. TODO: load balancing is messy. Can we exclude this from the MVP and just say each query must come from a specific node? Or: actually work out what problems this will cause and mitigate them.

    2. If the question has a `SubjectIdentity` requirement, the answering node is added to the identity set. TODO: we have deduced that it's not appropriate for matcing requirements to be on the query. Instead, metadata should contain databases, and the queries should link to what database they must query. Then the database contains the `Requirements`.
    3. The node looks up which subsequent questions must be answered to formulate the answer.
    4. Steps 1-3 are repeated until the query has been fully resolved down to it's fundamental questions. The node now has a set of nodes which will require the subject identity. TODO: need to resolve the `Choices` of the lower level questions too. How do we present these to the user?
    5. The node looks up the matching requirement entries for the identity set nodes and computes any fields marked as `optional` that are shared by two or more nodes. The node must submit these fields to all DAs that support them to ensure matching consistency (these fields are then considered `required`).
    6. The node then has both the fields required and fields that may subsequently be used for disambiguation or confidence-building for matching (the "match target").

2. The node presents a data entry screen for each matching field to the user. TODO: can't assume we're going to get them from the user. Just specify that they are submitted. DA must match using all fields that are sent, even if it doesn't think it requires them.

    0. TODO: nodes should receive the mininum amount od data required to do their job. When a node operates, it should use all the data it was given to verify as much correctness as possible.
    1. It is up to the node to decide what user interface is used and which fields are asked up front. The required fields are the minimum set, but the node may ask for all of the optional fields too.

3. Having received match target data, the node submits the match target along with a list of identity set nodes to an Identity Bridge listed in the metadata file. The identity bridge verifies, encrypts and signs the identity for each DA in the identity set. TODO: one query, one node. TODO: does the match target data come from the SP or the bridge in the Verify case?

    1. The node must also include a session key that will allow the identity set node to communicate in the reverse direction. This is so the identity set node can communicate with the asking node without learning it's identity, and therefore what the query is likely to be. TODO: don't send the session key to the bridge, it doesn't need it. instead just encrypt it for the... oh dear, because now the SP would have to sign the key and the DA would know who it was. We need to just give the DA the SP identity and then rely on LOGGING to bust them if they are abused. But uh oh, killer question: **how does the audit server know that the DA has lied? can we use canary queries for this?**

    ```protobuf
    message IdentitySignRequest {
      PersonIdentity subjectIdentity = 1;
      // TODO: also need to send the query that we want to run. Then identity bridge verifies.
      repeated Node identitySet = 2;
    }

    message PersonIdentity {
      string surname = 1;
      string postcode = 2;
      uint16 birthYear = 3;
      string initials = 4; // Initials in little endian Western order
      string firstName = 5; // TODO: remove this because it's hard to match, useless in the case of e.g. foster kids, shortenings?
      string houseNumber = 6;
      Date   dateOfBirth = 7; // TODO: what is data structure?
      // TODO: does this need to be a key-value structure (For namespacing?) How do we do confidence-building otherwise? For MVP, prob just keep it at DWP fields.. confidence fields should be key-value and relate to a type in the metadata.
    }

    message SignedIdentity {
      // TODO
    }
    ```

4. The node creates a payload containing the query to be run and the signed identity, and submits it to a consent service listed in the metadata file. The consent service returns a `SignedQuery` if it's conditions are met or a `BadQueryResponse` if not.

    1. The consent service checks that the query is allowed to be asked for this subject now. How it does this is implementation-dependent, but a scheme which asks the subject for their permission or requires an agent to assert they have gained permission is the intention. TODO more? 

    ```protobuf
    message Signed<T> {
      T payload = 1;
      bytes signature = 2;
    }

    message Query {
      string name = 1;
      repeated Param inputs = 2;
      SignedIdentity subjectIdentity = 3;
      PersonIdentity delegateIdentity = 4;
      ClientIdentity agentIdentity = 5;
      ServiceIdentity serviceIdentity = 6;
      bytes queryId = 7;
      repeated Choice choices = 8;
      // TODO: queryId same across all nodes?
    }
    ```

5. The sending node sends the signed query to the first hop node.

    1. The sending node should redact the identity fields that are `optional` using the object hashing method TODO.
    
5. The receiving node checks the query is valid using it's metadata file. If it is invalid, it returns a `BadQuery` response. Receiving nodes should check that:

    0. The metadata versions are the same
    1. It can answer the query
    2. The sending node (service) has authorization to ask that query (by checking the permissions/DSA) TODO: work out how to do same department permissions vs cross-department DSAs. "Smart nodes" e.g. proxies need permissions that are not listed in the metadata, pairs of nodes in metadata can use DSAs
    3. The query is allowed to be run for this subject (by checking the appropriate consent server authorisation)
    4. No checks are made on the agent and delegate identities (this is handled by the consent server)
    6. The identity has been encrypted for the all the nodes that will need it (and not more)
    7. The identity contains all the fields required and shared between all of the nodes (as above)

    ```protobuf
    message BadQueryResponse {
      enum Reason = {
        StaleMetadata = 0;
        CannotAnswerQuery = 1;
        ServiceUnauthorized = 2;
        NoConsentToken = 3; // TODO requirements model?
        AgentUnauthorized = 4;
        DelegateUnauthorized = 5;
        MissingIdentity = 6;
        IdentityTooOpen = 7;
        MissingIdentityFields = 8;
      } // TODO: NCSC: how detailed is this in non-debug?

      bytes queryId = 1;
      Reason reason = 2;
    }

6. The receiving node starts running the query.

    1. If it encouters a peice of data that is required from another node, it forms a `Query` payload of it's own and submits that to the next node.

        0. The `name` and `inputs` are defined by whatever information it needs from the next node.
        1. The identities are copied verbatim from the received `Query`.
        2. The `queryId` should be the same as the received `Query`.

    2. If it encounters a peice of data that is required from a database it has access to, it decrypts and attempts to match the `subjectIdentity` to it's database. This process is implementation-dependent.

    ```protobuf
    message QueryResponse {
      bytes queryId = 1;
      oneof result = {
        ValueResponse valueResponse = 1;
        MoreIdentityResponse moreIdentityResponse = 2;
        NoMatchResponse noMatchResponse = 3;
      }
    }
    ```

    All of the responses to a query are wrapped in a `QueryResponse`.

      1. If the node decides it wants more information to disambiguate or build confidence in the match, it should send a `MoreIdentityResponse` encrypted with the session key and containing details of the fields required.

      ```protobuf
      message MoreIdentityResponse {
        message IdentityFields {
          repeated string fields = 1;
        }

        bytes encryptedIdentityFields = 1;
      } // TODO: encryption
      ```

      2. If the node decides it cannot match the identity, it must send a `NoMatchResponse`. 

      ```protobuf
      message NoMatchResponse {
      } 
      ```

    3. If the node successfully completes the query, it returns the result as a `ValueResponse`.

    ```protobuf
    message ValueResponse {
      repeated ParamValue outputs = 1;
      // TODO: attribute standards fields, e.g. currency, expiry
    }
    ```

7. The node returns it's result of running the query 