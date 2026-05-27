# Stage 1: Build the React app
FROM node:lts-alpine AS builder

WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY package.json yarn.lock ./

# Install dependencies with frozen lockfile for reproducibility
RUN yarn install --frozen-lockfile

# Copy the rest of the source code
COPY . .

# Build the production bundle
RUN yarn build

# Stage 2: Serve the static files
FROM node:lts-alpine AS runner

WORKDIR /app

# Install the 'serve' package globally
RUN yarn global add serve

# Copy only the production build from the builder stage
COPY --from=builder /app/build ./build

EXPOSE 3000

CMD ["serve", "-s", "build", "-l", "3000"]
