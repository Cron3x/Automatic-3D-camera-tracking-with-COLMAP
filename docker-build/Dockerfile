FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=/opt/colmap-prefix
ENV NUM_CORES=$(nproc)

WORKDIR /home/ubuntu/

RUN apt-get update && apt-get install -y \
    tar \
    curl \
    wget \
    ca-certificates

RUN apt-get -y install \
    git \
    cmake \
    ninja-build \
    build-essential \
    libboost-program-options-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libeigen3-dev \
    libfreeimage-dev \
    libmetis-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libgmock-dev \
    libsqlite3-dev \
    libglew-dev \
    qt6-base-dev \
    libqt6opengl6-dev \
    libqt6openglwidgets6 \
    libcgal-dev \
    libceres-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libmkl-full-dev \
    libblas-dev \
    gfortran \
    liblapack-dev

RUN apt-get install -y \
    nvidia-cuda-toolkit \
    nvidia-cuda-toolkit-gcc


RUN wget -O "colmap-source.tar.gz" "https://github.com/colmap/colmap/archive/refs/tags/3.13.0.tar.gz"
RUN tar -xvzf ./colmap-source.tar.gz
RUN ls
WORKDIR /home/ubuntu/colmap-3.13.0
RUN mkdir build
WORKDIR /home/ubuntu/colmap-3.13.0/build
RUN cmake .. -GNinja -DBLA_VENDOR=Intel10_64lp -DCMAKE_CUDA_ARCHITECTURES=all
RUN ninja
