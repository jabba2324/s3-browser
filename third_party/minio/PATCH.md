# Local patch

This is a vendored copy of [`minio` v3.5.8](https://pub.dev/packages/minio),
pinned via `dependency_overrides` in the app's `pubspec.yaml`, with one
change on top of upstream.

## Why

`MinioClient.getRequestUrl()` (in `lib/src/minio_client.dart`) built the
actual request URL with `Uri(pathSegments: ...)`, which uses Dart's lenient
RFC 3986 encoding - this leaves sub-delimiter characters (`& ( ) ! * ' + , ; =`)
unescaped in the real request path. Meanwhile, `encodePath()` (in
`lib/src/minio_helpers.dart`), used to compute the SigV4 signature, escapes
those same characters per AWS's stricter canonical-URI rules. The signature
and the actual request therefore disagreed for any object key containing one
of those characters.

Real AWS S3 and MinIO-the-server both document this as the client's
responsibility to get right (AWS's own signing docs warn that "the standard
UriEncode functions provided by your development platform might not work"
for exactly this reason), and some S3-compatible servers (e.g. Garage)
enforce it strictly: uploading, downloading, or deleting an object whose key
contains one of these characters failed with `403 Forbidden: Invalid
signature`.

## What changed

Added `_strictEncodeSegment()` in `minio_client.dart`, using the same
character rules as `encodePath()`, and changed `getRequestUrl()` to build
the request URL from a pre-encoded path string via `Uri.parse()` (which
preserves existing `%XX` escapes) instead of `Uri(pathSegments: ...)`
(which would double-encode them). This makes the signed canonical path and
the actually-sent request path identical by construction.

Verified against a local Garage server and against a real hosted
S3-compatible endpoint: upload, list, presigned download (with byte
verification), and delete all pass for keys containing spaces and
`( ) & ' !` - see the project's git history for the reproduction and fix
verification.

## Updating this vendor copy

To pick up a new upstream `minio` release, re-copy the package from
`~/.pub-cache/hosted/pub.dev/minio-<version>` and re-apply the diff against
`lib/src/minio_client.dart` described above (`_strictEncodeSegment` plus the
`getRequestUrl` body). Worth checking first whether upstream has merged a
fix of their own - see https://github.com/xtyxtyx/minio-dart/pulls for
related open encoding-fix PRs (#114, #115) at the time this was written.
