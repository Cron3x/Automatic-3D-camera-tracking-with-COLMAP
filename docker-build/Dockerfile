FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=/opt/colmap
ENV NUM_CORES=$(nproc)

ARG USE_CUDA=1

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

RUN wget -O "colmap-source.tar.gz" "https://github.com/colmap/colmap/archive/refs/tags/3.13.0.tar.gz"
RUN tar -xvzf ./colmap-source.tar.gz

RUN wget -O "glomap-source.tar.gz" "https://github.com/colmap/glomap/archive/refs/tags/1.2.0.tar.gz"
RUN tar -xvzf ./glomap-source.tar.gz

FROM base AS base-cuda
ARG USE_CUDA
RUN if [ "$USE_CUDA" -eq 1 ]; then \
      apt-get install -y nvidia-cuda-toolkit nvidia-cuda-toolkit-gcc; \
      fi

FROM base-cuda AS colmap

WORKDIR /home/ubuntu/colmap-3.13.0
RUN mkdir build
WORKDIR /home/ubuntu/colmap-3.13.0/build
RUN if [ "$USE_CUDA" -eq 1 ]; then \
  cmake .. -GNinja -DBLA_VENDOR=Intel10_64lp -DCMAKE_CUDA_ARCHITECTURES=all; \
  else \
  cmake .. -GNinja -DBLA_VENDOR=Intel10_64lp; \
  fi
RUN ninja

FROM colmap AS glomap

WORKDIR /home/ubuntu/glomap-1.2.0
RUN mkdir build
WORKDIR /home/ubuntu/glomap-1.2.0/build
RUN if [ "$USE_CUDA" -eq 1 ]; then \
  cmake .. -GNinja -DCMAKE_CUDA_ARCHITECTURES=all; \
  else \
  cmake .. -GNinja; \
  fi
RUN ninja
