import express from "express";
import multer, { memoryStorage } from "multer";
import { extname } from "path";

const app = express();
const PORT = process.env.PORT || 3000;
const API_GATEWAY_URL = process.env.API_GATEWAY_URL;

if (!API_GATEWAY_URL) {
  console.error("ERROR: API_GATEWAY_URL no está configurado");
  console.error(
    "Ejemplo: export API_GATEWAY_URL=https://abc123.execute-api.us-east-1.amazonaws.com",
  );
  process.exit(1);
}

const upload = multer({
  storage: memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp/;
    const extOk = allowed.test(extname(file.originalname).toLowerCase());
    const mimeOk = allowed.test(file.mimetype);

    if (extOk && mimeOk) {
      cb(null, true);
    } else {
      cb(new Error(`Formato no permitido. Solo: jpg, png, gif, webp`), false);
    }
  },
});

app.post("/upload", upload.single("image"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No se recibió ningún archivo" });
  }

  console.log(
    `Reenviando archivo: ${req.file.originalname} (${req.file.size} bytes) → ${API_GATEWAY_URL}/upload`,
  );

  try {
    const formData = new FormData();
    const blob = new Blob([req.file.buffer], { type: req.file.mimetype });
    formData.append("file", blob, req.file.originalname);

    const response = await fetch(`${API_GATEWAY_URL}/upload`, {
      method: "POST",
      body: formData,
    });

    const responseBody = await response.json();

    res.status(response.status).json(responseBody);
  } catch (error) {
    console.error("Error reenviando a API Gateway:", error);
    res.status(502).json({
      error: "Error al comunicarse con el servicio de procesamiento",
      details: error.message,
    });
  }
});

app.use((err, req, res, next) => {
  if (err.code === "LIMIT_FILE_SIZE") {
    return res.status(413).json({ error: "Archivo excede el límite de 10 MB" });
  }
  res.status(400).json({ error: err.message });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`API corriendo en http://0.0.0.0:${PORT}`);
  console.log(`Reenviando uploads a: ${API_GATEWAY_URL}`);
});
