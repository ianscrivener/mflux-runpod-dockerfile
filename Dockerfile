FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# ---- Version pins (set in docker-bake.hcl) ----
# ARG MFLUX_SHA
# ARG RUNPODDIRECT_SHA

# ---- CUDA variant (set in docker-bake.hcl per target) ----
ARG CUDA_VERSION_DASH=13-2

# Install minimal dependencies needed for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    ca-certificates \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    openssh-server \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends cuda-minimal-build-${CUDA_VERSION_DASH} libcusparse-dev-${CUDA_VERSION_DASH} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm cuda-keyring_1.1-1_all.deb \
    && rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1

# Install pip and pip-tools for lock file generation.
RUN curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.12 get-pip.py "pip==26.1.2" && \
    python3.12 -m pip install --no-cache-dir "pip-tools==7.6.0" && \
    rm get-pip.py

# Set CUDA environment for building
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64

# Download pinned source archives
WORKDIR /tmp/build

# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1

# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install uv (latest) using official installer and create isolated venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment for all subsequent commands
ENV PATH="/opt/venv/bin:${PATH}"

# Go back to the root
WORKDIR /app

# Install Python runtime dependencies for the handler
RUN uv pip install pip runpod requests websocket-client

# Install MLX and verify installation
RUN uv pip install --no-cache "mlx[cuda]==0.32.0" \
    && python -c 'import mlx.core as mx; print("MLX:", mx.__version__)'

# Clone mflux source (pin with MFLUX_SHA, defaults to main)
# Remove torch from the mflux dependencies, then install mflux and verify
RUN git clone https://github.com/mflux-community/mflux.git /tmp/mflux \
    && sed -i '/^[[:space:]]*"torch[>=<~! ]/d' /tmp/mflux/pyproject.toml \
    && uv pip install --no-cache /tmp/mflux \
    && python -c 'from importlib.metadata import version; print("mflux:", version("mflux"))' \
    && rm -rf /tmp/mflux

# Copy your handler code
COPY handler.py .

# Start script for a Pod and for a serverless worker (see start.sh)
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Command to run when the container starts
CMD [ "/start.sh" ]

