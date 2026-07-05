FROM gcr.io/oss-fuzz-base/base-builder-python:v1@sha256:fce2290f3c86b52b2196a7f50bc9144d7de2182d7635b1c24bf2121289231dc6

RUN pip3 install --no-cache-dir \
    boto3==1.43.40 \
    botocore==1.43.40 \
    cryptography==49.0.0 \
    PyJWT==2.13.0 \
    requests==2.34.2

COPY . $SRC/forge
WORKDIR $SRC/forge
COPY .clusterfuzzlite/build.sh $SRC/
