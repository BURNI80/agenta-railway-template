# syntax=docker/dockerfile:1
#
# Thin wrapper around the upstream SeaweedFS image used as Agenta's bundled
# durable object store.
#
# The stock image starts `weed server` without the advanced IAM configuration,
# so the STS AssumeRoleWithWebIdentity handshake the API uses to mint
# store-scoped credentials would not exist and every agent mount would fail.
# entrypoint.sh renders s3.json + iam.json from the service's environment and
# then starts the server with the IAM engine enabled. See entrypoint.sh.
#
# The base is pinned on purpose: the advanced IAM subsystem has regressed
# across SeaweedFS releases, and anything below 4.42 keeps listing a
# pre-versioning object after its delete marker is written (a deleted file
# reappears in a mount, unreadable). 4.47 is the version Agenta ships.
FROM chrislusf/seaweedfs:4.47

COPY entrypoint.sh /usr/local/bin/railway-seaweedfs-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-seaweedfs-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-seaweedfs-entrypoint.sh"]
