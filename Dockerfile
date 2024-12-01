FROM ubuntu:24.04 AS linux-builder

ENV LINUX=/linux 

RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install --fix-missing -y git build-essential gcc g++ fakeroot libncurses5-dev libssl-dev ccache dwarves libelf-dev \
 cmake mold \
 libdw-dev libdwarf-dev \
 bpfcc-tools libbpfcc-dev libbpfcc \
 linux-headers-generic \
 libtinfo-dev \
 libstdc++-11-dev libstdc++-12-dev \
 bc \
 flex bison \
 rsync \
 libcap-dev libdisasm-dev binutils-dev unzip \
 pkg-config lsb-release wget software-properties-common gnupg zlib1g llvm \
 qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virtinst libvirt-daemon xterm attr busybox openssh-server \
 iputils-ping kmod 
RUN DEBIAN_FRONTEND=noninteractive apt-get install --fix-missing -y iproute2

RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh
RUN ./llvm.sh 19
RUN ln -s /usr/bin/clang-19 /usr/bin/clang
RUN ln -s /usr/bin/clang++-19 /usr/bin/clang++
RUN ln -s /usr/bin/ld.lld-19 /usr/bin/ld.lld
RUN DEBIAN_FRONTEND=noninteractive apt-get install --fix-missing -y curl

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install cross

# dependencies for building prevail
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 libboost-dev \
 libyaml-cpp-dev \
 libboost-filesystem-dev \
 libboost-program-options-dev

 # build prevail
RUN mkdir verifiers
WORKDIR /verifiers
RUN git clone --recurse-submodule https://github.com/vbpf/ebpf-verifier.git prevail
RUN sed -i 's/VERIFIER_ENABLE_TESTS "Build tests" OFF/VERIFIER_ENABLE_TESTS "Build tests" ON/' prevail/CMakeLists.txt
WORKDIR /verifiers/prevail
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --parallel `nproc`

# Build Exoverifier
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Alias python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install Lean
WORKDIR /verifiers
RUN wget https://github.com/leanprover-community/lean/releases/download/v3.42.1/lean-3.42.1-linux.tar.gz
RUN tar -xzf lean-3.42.1-linux.tar.gz -C /usr/local
ENV PATH="/usr/local/lean-3.42.1-linux/bin:${PATH}"
RUN lean --version

# Build Exoverifier
WORKDIR /verifiers
RUN git clone --recurse-submodules https://github.com/uw-unsat/exoverifier.git
WORKDIR /verifiers/exoverifier/lean

# Build dependencies and Exoverifier
RUN ./build-deps.sh && \
    make bpf-examples && \
    leanpkg configure && \
    leanpkg build && \
    leanpkg test