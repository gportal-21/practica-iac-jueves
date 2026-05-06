# Usa Node 20 LTS (incluye fetch y FormData nativos)
FROM node:20-alpine

WORKDIR /app

COPY package.json ./

RUN npm install

COPY index.js ./

EXPOSE 3000

CMD ["node", "index.js"]

# docker build -t image-processor-client .

# docker run -d -p 3000:3000 -e API_GATEWAY_URL=replace_with_actual_url --name image-client image-processor-client
