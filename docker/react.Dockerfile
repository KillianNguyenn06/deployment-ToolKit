# syntax=docker/dockerfile:1

ARG NODE_VERSION=22
ARG NODE_BUILD_MEMORY_MB=768

FROM node:${NODE_VERSION}-bookworm-slim AS builder

WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=${NODE_BUILD_MEMORY_MB}"

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.27-alpine

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
