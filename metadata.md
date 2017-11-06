# Federation Metadata

1. The system must be configured with the location of a public federation metadata file.

    0. Metadata is represented using a Protocol Buffer structure.

    ```protobuf
    syntax = "proto2";
    package Aquae.Metadata;
    option java_package           = "uk.gov.Aquae.ProtocolBuffers";
    option java_outer_classname   = "Metadata";
    option java_multiple_files    = false;
    option java_string_check_utf8 = true;
    option java_generic_services  = false;
    ```

    1. All communicating systems must share the same version of the federation metadata.

    ```protobuf
    message Validity {
      optional string version = 1;
      optional string validFrom = 2; // string of RFC-3339
      optional string validTo = 3;
    }

    message Endpoint {
      optional string hostname = 1; // must be a domain name, a dotted quad IPv4 or an IPv6 enclosed in square brackets.
      optional int32  port_number = 2;
    }

    // DSA contains the parties (from/to), the consent requirements, the identity/confidence attributes, parameters, return values, what the purpose is (lo-level), when (if citizen is present, recurrance etc.), validity dates, justification (hi-level scope), legal basis, how (Aquae network?)
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
      message UnencryptedIdentity { repeated MatchingSpec.IdFields identityFields = 1; }
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
        // SP can execute query when other business process dictate that it's required (i.e. legacy form, user unaware of Aquae)
      }
      message TransparencyRequirement {
        // Requires user to have seen the query plan and a record of this from consent/transparency server
        optional Endpoint transparencyServer = 1; // TODO: node name
      }
    }

    // TODO: Query contains the identity/confidence attributes, parameters, return values
    message QuerySpec {
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
      repeated IdFields disambiguator = 2;
      repeated string confidence = 3;
    }

    message ImplementingNode {
      optional string name = 1;
      optional MatchingSpec matchingRequirements = 2; // Can be empty
    }

    ```

    Each `Choice` message specifies one set of dependencies that a particular Query may have. These dependencies take the form of a list of other Querys whose answers are required. The set of all `Choice` messages constitues a Directed Acyclic Graph of Querys and implementations MUST enforce this property. i.e it MUST ensure that there are no query loops and MUST raise an error if they encounter Metadata files that contain loops.

    If a Query needs a result from a specific other Query more than once (for example, with different parameters) then it MUST appear more than once in the `requiredQuery` list. It MUST appear the maximum number of times that a single invocation of the Query will call it.

    ```protobuf
    message Choice {
      repeated string requiredQuery = 1;
    }

    message Node {
      optional string name = 1; // Can be any valid UTF-8 string.
      optional Endpoint location = 2;
      optional bytes certificate = 3; // X509 certificate in DER format
    }

    message ConfidenceAttribute {
      optional string name = 1;
      optional string description = 2;
      // TODO: confirm if type model is required
    }

    message Federation {
      optional Validity validity = 1;
      repeated Node node = 2;
      repeated DSA agreement = 3;
      repeated QuerySpec query = 4;
      repeated ConfidenceAttribute confidenceAttribute = 5;
    }
    ```
