FROM gcr.io/oss-fuzz-base/base-builder-python:v1@sha256:6b2b3a7e4a2da50de47f94925cffbe34747e1aae4f33d7f07ba6c681dd648b23

RUN pip3 install --no-cache-dir \
    boto3==1.43.40 \
    botocore==1.43.40 \
    cryptography==49.0.0 \
    PyJWT==2.13.0 \
    requests==2.34.2

COPY . $SRC/forge
WORKDIR $SRC/forge
COPY .clusterfuzzlite/build.sh $SRC/
