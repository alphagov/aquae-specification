# Functional Specification v0.2

## Transport Protocol

1. PDE nodes will establish connections over TCP.

    1. Nodes will accept connections on TCP on the port advertised in the metadata file. 

2. All connections to the TCP port must use TLS.

    1. All TLS connections MUST only use the algorithms and cipher suites permitted by the TLS v1.3 specification.
    TODO: is TLS v1.3 all authenticated encyption (e.g. MACed, so GCM, AEAD)
    2. Nodes SHOULD use TLS v1.3 where available, but MAY use TLS v1.2, as long as the above requirement is obeyed.

3. Both nodes on the TLS connection MUST supply certificates to the other party (mutual TLS).

    1. The submitted certificate MUST match the node's entry in the metadata file. TODO: does this allow virtual hosting, where we host multiple query servers from the same port? Do we want to do that?
    2. If a node submits a certificate that is not in the metadata file entry for that node, the connection MUST be dropped immediately.

4. TODO doesn't cover how the messaging protocol is sat on top. Any other conditions e.g. disconnecting?

## Metadata

1. The system must be configured with the location of a public metadata file.

    0. Metadata is represented using a Protocol Buffer structure.

    ```protobuf
    syntax = "proto2";
    ```

    1. All communicating systems must share the same version of the metadata.

    ```protobuf
    message Validity {
      optional string version = 1;
      optional string validFrom = 2; // string of RFC-3339
      optional string validTo = 3;
    }

    message Endpoint {
      optional string ipAddress = 1;
      optional uint32 portNumber = 2;
    }

    // DSA contains the parties (from/to), the consent requirements, the identity/confidence attributes, parameters, return values, what the purpose is (lo-level), when (if citizen is present, recurrance etc.), validity dates, justification (hi-level scope), legal basis, how (PDE?)
    // Parties that cannot decrypt the data do not need to be in the DSA.
    // Identity bridge server does require being in the DSA and the other two parties must agree on this choice
    // TODO: we will need to include clauses in the agreement that people will not attempt to get access to this data (cannot store it even if they can due to bad crypto)
    // TODO: does the final DA that processes the identity need to be part of the same DSA as the identity bridge?

    // Is the relationship between SP <-> QS and QS <-> DA the same DSA? Or do you need one each?
    message SharingLink {
      optional string nodeFrom = 2;
      optional string nodeTo = 3;

      message Question { optional string queryName = 1; } // TODO: query params should NOT contain PII
      message Answer { optional string queryName = 1; } // TODO: return values should be in here
      message UnencryptedIdentity { repeated MatchingSet::Fields identityFields = 1; }
      message EncryptedIdentity { }
      message ConfidenceAttributes { repeated string types = 1; }

      oneof what {
        Question question = 4;
        Answer answer = 5;
        UnencryptedIdentity uid = 6;
        EncryptedIdentity eid = 7;
        ConfidenceAttributes con = 8;
        // TODO: do we need both identity fields?
      }
    }

    message DSA {
      repeated SharingLink link = 1;
      optional string justification = 2; // TODO be more clear about what this is
      optional Validity validity = 3;
      optional string scope = 4;
      optional string legalBasis = 5;
      oneof requiredPermission {
        ConsentRequirement consent = 6;
        OnDemandRequirement onDemand = 7;
        TransparencyRequirement transparency = 8;
      }
      oneof recurrance {
        DoesNotRecur oneShot = 9;
      }

      message DoesNotRecur {
      }

      message ConsentRequirement {
        // Requires user to give explicit consent through a consent server
        optional Endpoint consentServer = 1;
      }
      message OnDemandRequirement {
        // SP can execute query when other business process dictate that it's required (i.e. legacy form, user unaware of PDE)
      }
      message TransparencyRequirement {
        // Requires user to have seen the query plan and a record of this from consent/transparency server
        optional Endpoint transparencyServer = 1; // TODO: node name
      }
    }

    // TODO: Query contains the identity/confidence attributes, parameters, return values
    message Query {
      optional string name = 1;
      repeated ImplementingNode node = 2;
      repeated Choice choice = 3;
    }

    message MatchingSpec {
      enum IdFields {
        SURNAME = 1;
        POSTCODE = 2;
        YEAR_OF_BIRTH = 3;
        INITIALS = 4;
        HOUSE_NUMBER = 6;
        DATE_OF_BIRTH = 7;
      }

      repeated IdFields required = 1;
      repeated IdFields disambiguators = 2;
      repeated string confidenceBuilders = 3;
    }

    message ImplementingNode {
      optional string nodeId = 1;
      optional MatchingSpec matchingRequirements = 2; // Can be empty
    }

    message Choice {
      repeated string requiredQuery = 1;
    }

    message Node {
      optional string name = 1;
      optional Endpoint location = 2;
      optional bytes publicKey = 3;
    }

    message ConfidenceAttribute {
      optional string name = 1;
      optional string description = 2;
      // TODO: confirm if type model is required
    }

    message Metadata {
      optional Validity validity = 1;
      repeated Node node = 2;
      repeated DSA agreement = 3;
      repeated Query query = 4;
      repeated ConfidenceAttributes confidenceAttribute = 5;
    }
    ```

## Messaging Protocol

### Querying

0. When a node wishes to make a query, it looks up the query in the metadata file and examines the available `Choices` for the query. TODO: who looks at the meteadata? Is it the first node "within PDE" or is it another client library that is not in the metadata? E.g. there is a random webserver not part of the network communicating with a trusted PDE node, who looks at the metadata here?

    1. The node should, where possible, expose these choices to the user.

1. When a node has decided from the available `Choices`, it creates a query plan using the metadata file according to the following algorithm. 

    0. Start with a empty set of nodes which require the subject's identity (the "identity set").
    1. The node looks up which node can directly answer the question it wants answered (the "answering node") by examining the `ImplementingNodes`.

        1. If multiple nodes can answer the query, the node should load balance it's requests between all the nodes in the set. TODO: load balancing is messy. Can we exclude this from the MVP and just say each query must come from a specific node? Or: actually work out what problems this will cause and mitigate them.

    2. If the chosen node has a `MatchingSpec` requirement, the answering node is added to the identity set.
    3. The node looks up which subsequent questions must be answered to formulate the answer by examining the `requiredQuery` fields.
    4. Steps 1-3 are repeated until the query has been fully resolved and there are no further required queries. The node now has a set of nodes which will require the subject identity. TODO: need to resolve the `Choices` of the lower level questions too. How do we present these to the user?
    5. The node looks up the matching requirement entries for the identity set nodes and computes any fields marked as `disambiguating` that are shared by two or more nodes. The node must submit these fields to all DAs that support them to ensure matching consistency (these fields are then considered `required`).
    6. The node then has both the fields required and fields that may subsequently be used for disambiguation or confidence-building for matching (the "match target").

2. The node collects the data required by the identity set nodes. DA must match using all fields that are sent, even if it doesn't think it requires them.

    0. TODO: nodes should receive the mininum amount of data required to do their job. When a node operates, it should use all the data it was given to verify as much correctness as possible.
    1. It is up to the node to decide what user interface is used and which fields are asked up front. The required fields are the minimum set, but the node may ask for all of the disambiguating fields too.

3. Having received match target data, the node submits the match target along with a list of identity set nodes to an Identity Bridge with which it has a DSA in the scope of the query it wishes to perform. The identity bridge verifies, encrypts and signs the identity for each DA in the identity set. TODO: does the match target data come from the SP or the bridge in the Verify case? TODO: could/should the IdB run the UI for collection of data? We need to just give the DA the SP identity and then rely on LOGGING to bust them if they are abused. But uh oh, killer question: **how does the audit server know that the DA has lied? can we use canary queries for this?**

  ```protobuf
  message IdentitySignRequest {
    optional PersonIdentity subjectIdentity = 1;
    // TODO: also need to send the query that we want to run. Then identity bridge verifies.
    repeated string identitySetNodes = 2;
  }

  message PersonIdentity {
    optional string surname = 1;
    optional string postcode = 2;
    optional uint32 birthYear = 3;
    optional string initials = 4; // Initials in little endian Western order
    optional string houseNumber = 6;
    optional string dateOfBirth = 7; // As an RFC-3339 date
  }

  message SignedIdentity {
    // TODO: unecrpyted container containing Redactable<T> fields
    // ID bridge cannot leave fields empty -> all are required
  }
  ```

4. The node creates a payload containing the query to be run and the signed identity, and submits it to a consent service listed in the metadata file. The consent service signs the scope if it's conditions are met or a `BadQueryResponse` if not. The query servers then satisfy themselves that the query being asked of them makes sense within that scope.

    1. The consent service checks that the query is allowed to be asked for this subject now. How it does this is implementation-dependent, but a scheme which asks the subject for their permission or requires an agent to assert they have gained permission is the intention. TODO more?

    ```protobuf
    message Signed<T> {
      // TODO: this is invalid protobuf, how do we do this more generally?
      optional T payload = 1;
      optional bytes signature = 2;
    }

    message Question {
      optional string name = 1;
      // repeated Param inputs = 2; TODO: way of expressing this TBC
      optional string dsaId = 9; // TODO: interesting that this has ended up here. is it a dragon?
    }

    message Query {
      optional Question question = 1;
      optional bytes queryId = 2;
      optional SignedScope scope = 3;

      // The transaction-id of the scope is the digest. TODO: algorithm.
      message Scope {
        optional Question originalQuestion = 1;
        optional bytes nOnce = 2; // Monotonically increasing value set by CS
        optional SignedIdentity subjectIdentity = 3;
        optional PersonIdentity delegateIdentity = 4;
        optional ClientIdentity agentIdentity = 5;
        optional ServiceIdentity serviceIdentity = 6;
        repeated Choice choice = 8;
      }
    }

    message Redactable<T> {
      message RealValue {
        optional int salt = 1;
        optional T value = 2;
      }

      message EncryptedValue {
        optional bytes hash = 1;
        optional bytes blob = 2;
      }

      oneof {
        optional bytes hash = 1;
        optional RealValue value = 2;
        optional EncryptedValue encrypted = 3;
      }
    }

    message RedactableContainer<T> {
      optional T message = 1;
      optional bytes rootHash = 2;
      optional bytes signatureOfHash = 3;
      optional map<string, bytes> nodeKeys = 4;
    }

    SignedQuery = RedactableContainer<Query>
    ```

5. The sending node sends the signed query to the first hop node.

    1. The sending node should redact the identity fields that are optional using the object hashing method TODO: what i sthe object hashing method. c.f. Ben Laurie who is well known.

5. The receiving node checks the query is valid using it's metadata file. If it is invalid, it returns a `BadQuery` response. Receiving nodes should check that:

    0. The metadata versions are the same
    1. It can answer the query
    2. The sending node (service) has authorization to ask that query (by checking the permissions/DSA) TODO: work out how to do same department permissions vs cross-department DSAs. "Smart nodes" e.g. proxies need permissions that are not listed in the metadata, pairs of nodes in metadata can use DSAs
    3. The query is allowed to be run for this subject (by checking the appropriate consent server authorisation)
    4. No checks are made on the agent and delegate identities (this is handled by the consent server)
    6. The identity has been encrypted for the all the nodes that will need it (and not more)
    7. The identity contains all the fields required and shared between all of the nodes (as above)
    8. The transaction-id (the digest of the `Scope` object, not including the signature) has not been used before.

    ```protobuf
    message BadQueryResponse {
      enum Reason = {
        StaleMetadata = 0;
        CannotAnswerQuery = 1;
        ServiceUnauthorized = 2;
        NoConsentToken = 3;
        AgentUnauthorized = 4;
        DelegateUnauthorized = 5;
        MissingIdentity = 6;
        IdentityTooOpen = 7;
        MissingIdentityFields = 8;
      } // TODO: NCSC: how detailed is this in non-debug?

      optional bytes queryId = 1;
      optional Reason reason = 2;
    }
    ```

6. The receiving node starts preparing the query.

    1. If it encouters a peice of data that is required from another node, it forms a `Query` payload of it's own and submits that to the next node.

        1. The `name` and `inputs` are defined by whatever information it needs from the next node. The `dsaId` is picked from the metadata based on the `scope`.
        2. The `scope` is copied from the previous query.
        3. The `queryId` is a unique id that identifies the conversation between two nodes (as distinct from the transaction-id, which identifies all the conversations answering the highest-level question).

    2. If it encounters a peice of data that is required from a database it has access to, it decrypts and attempts to match the `subjectIdentity` to it's database. This process is implementation-dependent.

    ```protobuf
    message QueryResponse {
      optional bytes queryId = 1;
      oneof result = {
        ValueResponse valueResponse = 1;
        MoreIdentityResponse moreIdentityResponse = 2;
        NoMatchResponse noMatchResponse = 3;
      }
    }
    ```

    All of the responses to a query are wrapped in a `MatchingResponse`.

      1. If the node decides it wants more information to disambiguate or build confidence in the match, it should send a `MoreIdentityResponse` encrypted with the session key and containing details of the fields required.

      ```protobuf
      message MoreIdentityResponse {
        message IdentityFields {
          repeated string fields = 1;
        }

        optional bytes encryptedIdentityFields = 1;
      } // TODO: encryption
      ```

      2. If the node decides it has finished matching and it is ready to proceed (either because it has a high-confidence single result, or because it cannot match the identity), it must send a `MatchCompleteResponse`.

      ```protobuf
      message MatchCompleteResponse {
      } 
      ```

    Intermediate servers must pass through the encrypted responses to the origin node.

7. If any of the nodes return a `MoreIdentityResponse`, the SP must resubmit the `Query` message with unredacted identity fields.

    1. The identity message must contain exactly the fields it did previously along with every field that was additionally requested by  one or more nodes.
    2. The same set of fields must be sent to each node.

7. When the origin node has received responses from all of the identity nodes, it sends a `SecondWhistle` message along the query path to tell the query servers to begin executing the query logic against the data from the matched records. Once the `SecondWhilste` has been processed, the node can finalise the transaction and clear resources - no further messages for this `queryId` are permitted.

    ```protobuf
    message SecondWhistle {
      optional bytes queryId = 1;
      // TODO: how do we ensure this comes from the SP??
    }
    ``` 

8. The nodes on the query path execute the query logic.

    1. If the node requires data from another node, it passes on the `SecondWhistle` message to that node and awaits the `QueryAnswer`. It is up to the node when and if it actually forwards the `SecondWhistle` message (for instance, it may concurrently request all data or it may wait until it has evaluated earlier branches in an OR-type condition). It should only send the `SecondWhistle` if it requires the data.

        ```protobuf
        message QueryAnswer {
          optional bytes queryId = 1;
          oneof result {
            ValueResponse value = 2;
            ErrorResponse error = 3;
          }
        }
        ```

    2. If the node has all the data required to run a query (either as data from a database it has access to or from responses from other nodes), it transforms the result according to the required query, and then returns a `ValueResponse`.

        ```protobuf
        message ValueResponse {
          repeated ParamValue outputs = 1;
          // TODO: attribute standards fields, e.g. currency, expiry
        }
        ```

    3. If the node fails to run the query, it returns an `ErrorResponse`.

        ```protobuf
        message ErrorResponse {
          // TODO
        }
        ```

    4. If it finishes a query and has not forwarded the `SecondWhilstle` message, it must instead send a `Finish` message to allow the subsequent nodes to clear resources.

        ```protobuf
        message Finish {
          optional bytes queryId = 1;
        }
        ```

9. That's it.