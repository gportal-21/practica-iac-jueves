import express from "express";
import multer, { memoryStorage } from "multer";
import { extname } from "path";

const app = express();
const port = 3000;

const upload = multer({
  storage: memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp/;
    const valid =
      allowed.test(extname(file.originalname).toLowerCase()) &&
      allowed.test(file.mimetype);
    cb(valid ? null : new Error("Solo se permiten imágenes"), valid);
  },
});

app.post("/upload", upload.single("image"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No se recibió ningún archivo" });
  }

  res.set("Content-Type", req.file.mimetype);
  res.send(req.file.buffer);
});

app.use((err, req, res, next) => {
  res.status(400).json({ error: err.message });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`API corriendo en http://0.0.0.0:${port}`);
});
