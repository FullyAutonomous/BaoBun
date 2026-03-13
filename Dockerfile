# BaoBun Docker Image
# Multi-stage build for optimized production image

# Build stage
FROM oven/bun:1 AS builder

WORKDIR /app

# Copy package files
COPY package.json bun.lock* ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy source code
COPY . .

# Build if needed (optional)
# RUN bun run build

# Production stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install BaoBun
ARG TARGETARCH
ARG VERSION=latest

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        ARCH="x64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        ARCH="arm64"; \
    else \
        ARCH="x64"; \
    fi && \
    if [ "$VERSION" = "latest" ]; then \
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/FullyAutonomous/BaoBun/releases/latest | grep '"browser_download_url":.*baobun-linux-'"$ARCH" | sed -E 's/.*"([^"]+)".*/\1/'); \
    else \
        DOWNLOAD_URL="https://github.com/FullyAutonomous/BaoBun/releases/download/$VERSION/baobun-linux-$ARCH.zip"; \
    fi && \
    curl -fsSL "$DOWNLOAD_URL" -o /tmp/baobun.zip && \
    unzip /tmp/baobun.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/bun && \
    rm /tmp/baobun.zip

# Create non-root user
RUN groupadd -r baobun && useradd -r -g baobun baobun

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER baobun

# Verify installation
RUN bun --version

# Default command
CMD ["bun", "--version"]
