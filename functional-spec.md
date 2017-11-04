# Functional Specification v0.2

This specification is in **ALPHA** and is liable to be changed or completely deleted at any time.

The specification consists of the following components. A new reader may like to read them in top-to-bottom order.

* [Transport Layer](./transport.md): Lower-level protocols used by for transport
* [Metadata](./metadata.md): Configuration format used by the system
* [Messaging Protocol](./messaging.md): Expected message sequences for running data queries


## Date Format

All calls for serialisations of dates or times by this specification MUST conform to the "date-time" production as defined in [RFC 3339](http://www.faqs.org/rfcs/rfc3339.html).

In addition, the following constraints also apply:

 + An uppercase "T" character MUST be used to separate date and time.
 + All date-times MUST be in UTC.
 + An uppercase "Z" character MUST be present: numeric time zone offsets MUST NOT be used.
 + The date-time serialisation MUST NOT contain any whitespace. Only characters specified by `[0-9TZ:.-]` are permitted.
 + Years MUST be specified using 4 digits.

 Note that RFC 3339 is more strict than the [W3C Date and Time Format](http://www.w3.org/TR/NOTE-datetime). In particular, all portions of the date and time must be present, with the exception of the fractional portions of the second, which MAY be omitted.

