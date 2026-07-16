FROM gcr.io/oss-fuzz-base/base-builder-python:v1@sha256:bfc9a983c445774ca98639477cc90c15f70a1493875848d62a08769023fc6676

RUN pip3 install --no-cache-dir \
    boto3==1.43.40 \
    botocore==1.43.40 \
    cryptography==49.0.0 \
    PyJWT==2.13.0 \
    requests==2.34.2

COPY . $SRC/forge
WORKDIR $SRC/forge
COPY .clusterfuzzlite/build.sh $SRC/
