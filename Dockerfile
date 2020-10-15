FROM osimis/orthanc-builder-base:20.4.0 as build-plugin-s3

# Install vcpkg and cryptopp
RUN apt-get --assume-yes update
RUN git clone --branch 2020.07 --depth 1 https://github.com/microsoft/vcpkg /sources/vcpkg
WORKDIR /sources/vcpkg
RUN ./bootstrap-vcpkg.sh
RUN ./vcpkg install cryptopp

# Install aws-sdk-cpp
RUN git clone --branch 1.8.42 --depth 1 https://github.com/aws/aws-sdk-cpp.git /sources/aws
RUN mkdir -p /source/aws-sdk-cpp
WORKDIR /build/aws-sdk-cpp
RUN cmake -DBUILD_ONLY="s3;transfer" /sources/aws
RUN make -j 4
RUN make install

# Build the AWS S3 plugin
RUN hg clone https://hg.orthanc-server.com/orthanc-object-storage/ -r tip /sources/orthanc-object-storage
WORKDIR /build/orthanc-object-storage
RUN cmake -DCMAKE_TOOLCHAIN_FILE=/sources/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DALLOW_DOWNLOADS=ON \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DUSE_SYSTEM_GOOGLE_TEST=ON \
    -DUSE_SYSTEM_ORTHANC_SDK=OFF \
    -DORTHANC_FRAMEWORK_VERSION=1.7.4 \
    /sources/orthanc-object-storage/Aws
RUN make -j 4

# Add the S3 plugin to the image
FROM osimis/orthanc:20.10.1
COPY --from=build-plugin-s3 /build/orthanc-object-storage/libOrthancAwsS3Storage.so /usr/share/orthanc/plugins-disabled/
COPY --from=build-plugin-s3 /usr/local /usr/local
COPY plugins-def-s3.json /startup/
