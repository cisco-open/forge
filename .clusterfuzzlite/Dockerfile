FROM gcr.io/oss-fuzz-base/base-builder-python:v1@sha256:3cb899359c06448afeabcffeefa9b814acb5040e391757a5790cdaa7d05ec520

RUN pip3 install --no-cache-dir \
    boto3==1.43.40 \
    botocore==1.43.40 \
    cryptography==49.0.0 \
    PyJWT==2.13.0 \
    requests==2.34.2

COPY . $SRC/forge
WORKDIR $SRC/forge
COPY .clusterfuzzlite/build.sh $SRC/
