FROM node:20-alpine
WORKDIR /app
RUN echo 'const http = require("http"); const server = http.createServer((req, res) => { res.writeHead(200, {"Content-Type": "application/json"}); res.end(JSON.stringify({status: "ok", message: "Railway test working!"})); }); server.listen(process.env.PORT || 10000, "0.0.0.0", () => console.log("Server running on port " + (process.env.PORT || 10000)));' > server.js
CMD ["node", "server.js"]
