FROM node:18-alpine AS server-dependencies

RUN apk -U upgrade \
  && apk add build-base python3 \
  --no-cache

WORKDIR /app

COPY server/package.json server/package-lock.json ./

RUN npm install npm --global \
  && npm install pnpm --global \
  && pnpm import \
  && pnpm install --prod

FROM node:lts AS client

WORKDIR /app

COPY client/package.json client/package-lock.json ./

RUN npm install npm --global \
  && npm install pnpm --global \
  && pnpm import \
  && pnpm install --prod

COPY client .
RUN DISABLE_ESLINT_PLUGIN=true npm run build

FROM node:18-alpine

RUN apk -U upgrade \
  && apk add bash \
  --no-cache

USER node
WORKDIR /app

COPY --chown=node:node start.sh .
COPY --chown=node:node server .
COPY --chown=node:node healthcheck.js .

RUN mv .env.sample .env

COPY --from=server-dependencies --chown=node:node /app/node_modules node_modules

COPY --from=client --chown=node:node /app/build public
COPY --from=client --chown=node:node /app/build/index.html views/index.ejs

# Use a single mount point for all volumes
VOLUME /app/data

# Create necessary subdirectories inside /app/data
RUN mkdir -p /app/data/user-avatars \
  && mkdir -p /app/data/project-background-images \
  && mkdir -p /app/data/attachments

EXPOSE 1337

HEALTHCHECK --interval=10s --timeout=2s --start-period=15s \
  CMD node ./healthcheck.js

CMD [ "bash", "start.sh" ]
