FROM node:22
WORKDIR /app
COPY package* ./
RUN npm install
COPY . .
CMD [ "node","app.js" ]
