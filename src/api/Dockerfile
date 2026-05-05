FROM node:18-alpine

WORKDIR /usr/src/app

COPY package.json .
RUN npm install --omit=dev

COPY index.js .


EXPOSE 3000

CMD ["node", "index.js"]

# docker build -t lab/api .
# docker run -p 3000:3000 lab/api
