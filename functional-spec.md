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

## Metadata

1. The system must be configured with the location of a public metadata file.

    1. All communicating systems must share the same version of the metadata.

    ```protobuf
    message Validity {
      string version = 1;
      Date validFrom = 2;
      Date validTo = 3;
    }

    message Endpoint {
      string ipAddress = 1;
      uint32 portNumber = 2;
    }

    // DSA contains the parties (from/to), the consent requirements, the identity/confidence attributes, parameters, return values, what the purpose is (lo-level), when (if citizen is present, recurrance etc.), validity dates, justification (hi-level scope), legal basis, how (PDE?)
    // Parties that cannot decrypt the data do not need to be in the DSA.
    // Identity bridge server does require being in the DSA and the other two parties must agree on this choice
    // TODO: we will need to include clauses in the agreement that people will not attempt to get access to this data (cannot store it even if they can due to bad crypto)
    // TODO: does the final DA that processes the identity need to be part of the same DSA as the identity bridge?

    // Is the relationship between SP <-> QS and QS <-> DA the same DSA? Or do you need one each?
    message SharingLink {
      string nodeFrom = 2;
      string nodeTo = 3;

      message Question { string queryName = 1; } // TODO: query params should NOT contain PII
      message Answer { string queryName = 1; } // TODO: return values should be in here
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
      string justification = 2; // TODO be more clear about what this is
      Validity validity = 3;
      string scope = 4;
      string legalBasis = 5;
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
        Endpoint consentServer = 1;
      }
      message OnDemandRequirement {
        // SP can execute query when other business process dictate that it's required (i.e. legacy form, user unaware of PDE)
      }
      message TransparencyRequirement {
        // Requires user to have seen the query plan and a record of this from consent/transparency server
        Endpoint transparencyServer = 1; // TODO: node name
      }
    }

    // TODO: Query contains the identity/confidence attributes, parameters, return values
    message Query {
      string name = 1;
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
      string nodeId = 1;
      MatchingSpec matchingRequirements = 2; // Can be empty
    }

    message Choice {
      repeated string requiredQuery = 1;
    }

    message Node {
      string name = 1;
      Endpoint location = 2;
      bytes publicKey = 3;
    }

    message ConfidenceAttribute {
      string name = 1;
      string description = 2;
      // TODO: confirm if type model is required
    }

    message Metadata {
      Validity validity = 1;
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
      // TODO: unecrpyted container containing Redactable<T> fields
      // ID bridge cannot leave fields empty -> all are required
    }
    ```

4. The node creates a payload containing the query to be run and the signed identity, and submits it to a consent service listed in the metadata file. The consent service signs the scope if it's conditions are met or a `BadQueryResponse` if not. The query servers then satisfy themselves that the query being asked of them makes sense within that scope.

    1. The consent service checks that the query is allowed to be asked for this subject now. How it does this is implementation-dependent, but a scheme which asks the subject for their permission or requires an agent to assert they have gained permission is the intention. TODO more? 

    ```protobuf
    message Signed<T> {
      T payload = 1;
      bytes signature = 2;
    }

    message Question {
      string name = 1;
      repeated Param inputs = 2;
      DSA legalAccess = 9; // TODO: interesting that this has ended up here. is it a dragon?
    }

    message Query {
      Question question = 1;
      bytes queryId = 2;
      Signed<Scope> scope = 3;

      // The transaction-id of the scope is the digest. TODO: algorithm.
      message Scope {
        Question originalQuestion = 1;
        bytes nOnce = 2; // Monotonically increasing value set by CS
        SignedIdentity subjectIdentity = 3;
        PersonIdentity delegateIdentity = 4;
        ClientIdentity agentIdentity = 5;
        ServiceIdentity serviceIdentity = 6;
        repeated Choice choice = 8;
      }
    }

    message Redactable<T> {
      message RealValue {
        int salt = 1;
        T value = 2;
      }

      message EncryptedValue {
        bytes hash = 1;
        bytes blob = 2;
      }

      oneof {
        bytes hash = 1;
        RealValue value = 2;
        EncryptedValue encrypted = 3;
      }
    }

    message RedactableContainer<T> {
      T message = 1;
      bytes rootHash = 2;
      bytes signatureOfHash = 3;
      map<string, bytes> nodeKeys = 4;
    }

    SignedQuery = RedactableContainer<Query>
    ```

5. The sending node sends the signed query to the first hop node.

    1. The sending node should redact the identity fields that are `optional` using the object hashing method TODO: what i sthe object hashing method. c.f. Ben Laurie who is well known.

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
    ```

6. The receiving node starts preparing the query.

    1. If it encouters a peice of data that is required from another node, it forms a `Query` payload of it's own and submits that to the next node.

        1. The `name` and `inputs` are defined by whatever information it needs from the next node. The `legalAgreement` is picked from the metadata based on the `scope`. TODO: metadata contains DSAs that are limited to specific scopes.
        2. The `scope` is copied from the previous query.
        3. The `queryId` is a unique id that identifies the conversation between two nodes (as distinct from the transaction-id, which identifies all the conversations answering the highest-level question).

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

    All of the responses to a query are wrapped in a `MatchingResponse`.

      1. If the node decides it wants more information to disambiguate or build confidence in the match, it should send a `MoreIdentityResponse` encrypted with the session key and containing details of the fields required.

      ```protobuf
      message MoreIdentityResponse {
        message IdentityFields {
          repeated string fields = 1;
        }

        Encrypted<IdentityFields> encryptedIdentityFields = 1;
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

7. When the origin node has received responses from all of the identity  nodes, it sends a `SecondWhistle` message along the query path to tell the query servers to begin executing the query logic against the data from the matched records. Once the `SecondWhilste` has been processed, the node can finalise the transaction and clear resources - no further messages for this `queryId` are permitted.

    ```protobuf
    message SecondWhistle {
      bytes queryId = 1;
      // TODO: how do we ensure this comes from the SP??
    }
    ``` 

8. The nodes on the query path execute the query logic.

    1. If the node requires data from another node, it passes on the `SecondWhistle` message to that node and awaits the `ExecResponse`. It is up to the node when and if it actually forwards the `SecondWhistle` message (for instance, it may concurrently request all data or it may wait until it has evaluated earlier branches in an OR-type condition). It should only send the `SecondWhistle` if it requires the data.

        ```protobuf
        message QueryAnswer {
          bytes queryId = 1;
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
          bytes queryId = 1;
        }
        ```

9. That's it.