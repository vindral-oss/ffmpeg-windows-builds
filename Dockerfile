FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    subversion \
    ragel \
    curl \
    texinfo \
    g++ \
    bison \
    flex \
    cvs \
    yasm \
    automake \
    libtool \
    autoconf \
    gcc \
    cmake \
    git \
    make \
    pkg-config \
    zlib1g-dev \
    unzip \
    pax \
    nasm \
    gperf \
    autogen \
    bzip2 \
    autoconf-archive \
    p7zip-full \
    meson \
    clang \
    python3 \
    python3-setuptools \
    wget \
    ed gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64

FROM base AS libx264

WORKDIR /
RUN git clone --depth 1 https://code.videolan.org/videolan/x264.git
WORKDIR /x264
RUN git checkout 0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee
RUN ./configure --host=x86_64-w64-mingw32 --disable-shared --enable-static --cross-prefix=x86_64-w64-mingw32- --prefix=/output || exit 1 && \
    make -j 12 && \
    make install

FROM base AS openssl

WORKDIR /
RUN git clone https://github.com/openssl/openssl
WORKDIR /openssl
RUN git checkout openssl-3.5.3
RUN ./Configure mingw64 -static --prefix=/output --libdir=/output/lib --cross-compile-prefix=x86_64-w64-mingw32- && \
    make -j$(( $(nproc) + 1)) && make install

FROM base AS libsrt

COPY --from=openssl /output /openssl

WORKDIR /
RUN git clone https://github.com/Haivision/srt.git
WORKDIR /srt
RUN git checkout v1.5.5-rc.0
RUN mkdir _build && cd _build && \
    OPENSSL_ROOT_DIR=/openssl cmake ../ -DCMAKE_CXX_FLAGS="-static-libgcc "  -DUSE_STATIC_LIBSTDCXX=1 -DENABLE_SHARED=0 -DENABLE_CXX11=0 -DENABLE_APPS=0 -DENABLE_STATIC=1 -DBUILD_SHARED_LIBS=1 -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ -DCMAKE_INSTALL_PREFIX=/output && \
    cmake --build . && make install

FROM base AS libogg

WORKDIR /
RUN git clone https://github.com/xiph/ogg.git
WORKDIR /ogg
RUN git checkout v1.3.6
RUN  ./autogen.sh && ./configure --host=x86_64-w64-mingw32 --disable-shared --enable-static --prefix=/output --disable-docs --disable-examples --disable-oggtest && \
     make -j$(( $(nproc) + 1)) && make install

FROM base AS libvorbis

COPY --from=libogg /output /usr/local/

WORKDIR /
RUN git clone https://github.com/xiph/vorbis.git
WORKDIR /vorbis
RUN git checkout v1.3.7
RUN ./autogen.sh
RUN ./configure CFLAGS="-I/usr/local/include" LDFLAGS="-static -L/usr/local/lib" \
 --host=x86_64-w64-mingw32 --disable-shared --enable-static --prefix=/output --disable-docs --disable-examples --disable-oggtest && \
     make -j$(( $(nproc) + 1)) && make install

FROM base AS nvheaders

WORKDIR /
RUN wget https://github.com/FFmpeg/nv-codec-headers/releases/download/n12.1.14.0/nv-codec-headers-12.1.14.0.tar.gz
RUN tar -xvf nv-codec-headers-12.1.14.0.tar.gz
WORKDIR /nv-codec-headers-12.1.14.0
RUN make -j$(( $(nproc) + 1)) && make install PREFIX=/output

FROM base AS zlib

RUN wget https://github.com/madler/zlib/archive/v1.3.1.tar.gz
RUN tar -xvf v1.3.1.tar.gz 
WORKDIR /zlib-1.3.1
RUN ./configure --prefix=/output --static
RUN make CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar PREFIX=$mingw_w64_x86_64_prefix RANLIB=x86_64-w64-mingw32-ranlib LD=x86_64-w64-mingw32-ld STRIP=x86_64-w64-mingw32-strip CXX=x86_64-w64-mingw32-g++ -j$(( $(nproc) + 1)) && make install PREFIX=/output

FROM base AS ffmpeg

ARG FFMPEG_VERSION=n6.1

COPY --from=libx264 /output /output
COPY --from=openssl /output /output
COPY --from=libsrt /output /output
COPY --from=libvorbis /output /output
COPY --from=libogg /output /output
COPY --from=nvheaders /output /output
COPY --from=zlib /output /output

ENV PKG_CONFIG_PATH=/output/lib/pkgconfig

WORKDIR /
RUN git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
WORKDIR /ffmpeg
RUN git checkout ${FFMPEG_VERSION}
RUN tar -czf /ffmpeg-source-${FFMPEG_VERSION}.tar.gz -C / ffmpeg
RUN ./configure --pkg-config=pkg-config --prefix=/ffmpeg-output --cross-prefix=x86_64-w64-mingw32- --arch=x86_64 --target-os=mingw32 \
    --enable-gpl --enable-openssl --enable-version3 --enable-libx264 --enable-zlib --enable-libvorbis --enable-nvenc --enable-nvdec --enable-libsrt \
    --extra-cflags="-I/output/include" --extra-ldflags="-static -L/output/lib" \
    --pkg-config-flags="--static" --enable-shared && \
    make -j$(( $(nproc) + 1)) && \
    make install

RUN p7zip -k /ffmpeg-output

