#!/bin/sh
#
# Railway SeaweedFS entrypoint for the Agenta bundled object store.
#
# Agenta's "mounts" feature (agent working directories, session attachments)
# talks to this store over the S3 protocol and, crucially, obtains short-lived
# credentials through STS AssumeRoleWithWebIdentity. SeaweedFS only authorizes
# that path when the *advanced IAM* config is present, so this entrypoint
# generates two config files from the environment before starting the server:
#
#   s3.json  - the single admin identity the API uses (access/secret key).
#   iam.json - the OIDC provider (pointing at the API's self-served JWKS) plus
#              the `agenta-store` role the API's web-identity token assumes.
#
# Both are derived from env only; nothing is committed to the image. Real S3 /
# R2 / MinIO ship their own STS/IAM and ignore all of this.
#
# Required env: AGENTA_STORE_ACCESS_KEY, AGENTA_STORE_SECRET_KEY,
#               AGENTA_STORE_SIGNING_KEY, AGENTA_STORE_JWT_ISSUER,
#               AGENTA_STORE_BUCKET
set -eu

mkdir -p /etc/seaweedfs /data

cat > /etc/seaweedfs/s3.json <<EOF
{"identities":[{"name":"agenta","credentials":[{"accessKey":"${AGENTA_STORE_ACCESS_KEY}","secretKey":"${AGENTA_STORE_SECRET_KEY}"}],"actions":["Admin","Read","Write","List","Tagging"]}]}
EOF

cat > /etc/seaweedfs/iam.json <<EOF
{"sts":{"tokenDuration":"1h","maxSessionLength":"12h","issuer":"seaweedfs-sts","signingKey":"${AGENTA_STORE_SIGNING_KEY}"},"providers":[{"name":"agenta","type":"oidc","enabled":true,"config":{"issuer":"${AGENTA_STORE_JWT_ISSUER}","clientId":"agenta-store","jwksUri":"${AGENTA_STORE_JWT_ISSUER}/.well-known/jwks.json"}}],"policies":[{"name":"store-rw","document":{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:*"],"Resource":["arn:aws:s3:::${AGENTA_STORE_BUCKET}","arn:aws:s3:::${AGENTA_STORE_BUCKET}/*"]}]}}],"roles":[{"roleName":"agenta-store","roleArn":"arn:aws:iam::role/agenta-store","attachedPolicies":["store-rw"],"trustPolicy":{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"agenta"},"Action":["sts:AssumeRoleWithWebIdentity"]}]}}]}
EOF

exec weed server \
    -dir=/data \
    -ip="$(hostname -i)" \
    -volume.max=64 \
    -s3 \
    -s3.port=8333 \
    -s3.config=/etc/seaweedfs/s3.json \
    -s3.iam.config=/etc/seaweedfs/iam.json
