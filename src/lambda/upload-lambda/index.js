const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { v4: uuidv4 } = require("uuid");
const Busboy = require("busboy");

const s3Client = new S3Client({});

const BUCKET = process.env.S3_BUCKET;
const UPLOAD_PREFIX = process.env.UPLOAD_PREFIX || "uploads/";

const MAX_SIZE_BYTES = 10 * 1024 * 1024;
const ALLOWED_FORMATS = ["jpeg", "png", "gif", "webp"];

function detectFormat(buffer) {
  if (buffer.length < 12) return null;

  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return "jpeg";
  }

  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return "png";
  }

  if (
    buffer[0] === 0x47 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x38
  ) {
    return "gif";
  }

  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return "webp";
  }

  return null;
}

function parseMultipart(bodyBuffer, contentType) {
  return new Promise((resolve, reject) => {
    const busboy = Busboy({ headers: { "content-type": contentType } });
    let fileData = null;

    busboy.on("file", (fieldname, fileStream, info) => {
      const { filename, mimeType } = info;
      const chunks = [];

      fileStream.on("data", (chunk) => chunks.push(chunk));
      fileStream.on("end", () => {
        fileData = {
          buffer: Buffer.concat(chunks),
          filename,
          mimeType,
        };
      });
    });

    busboy.on("finish", () => {
      if (!fileData) {
        reject(new Error("No file found in multipart body"));
      } else {
        resolve(fileData);
      }
    });

    busboy.on("error", reject);

    busboy.end(bodyBuffer);
  });
}

function parseJsonBase64(bodyString) {
  let parsed;
  try {
    parsed = JSON.parse(bodyString);
  } catch (e) {
    throw new Error("Body is not valid JSON");
  }

  if (!parsed.data) {
    throw new Error('JSON body must include "data" field with base64 content');
  }

  return {
    buffer: Buffer.from(parsed.data, "base64"),
    filename: parsed.filename || "unknown",
    mimeType: parsed.contentType || "application/octet-stream",
  };
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

exports.handler = async (event) => {
  console.log("Request received:", {
    method: event.requestContext?.http?.method,
    path: event.rawPath,
    contentType: event.headers?.["content-type"],
    isBase64: event.isBase64Encoded,
  });

  try {
    if (event.requestContext?.http?.method !== "POST") {
      return response(405, { error: "Method Not Allowed" });
    }

    if (!BUCKET) {
      console.error("S3_BUCKET env var not set");
      return response(500, { error: "Server misconfigured" });
    }

    const contentType = event.headers?.["content-type"] || "";
    let fileData;

    if (contentType.includes("multipart/form-data")) {
      const bodyBuffer = event.isBase64Encoded
        ? Buffer.from(event.body, "base64")
        : Buffer.from(event.body, "utf-8");

      fileData = await parseMultipart(bodyBuffer, contentType);
    } else if (contentType.includes("application/json")) {
      const bodyString = event.isBase64Encoded
        ? Buffer.from(event.body, "base64").toString("utf-8")
        : event.body;

      fileData = parseJsonBase64(bodyString);
    } else {
      return response(415, {
        error: "Unsupported Media Type",
        message: "Use multipart/form-data or application/json with base64 data",
      });
    }

    if (fileData.buffer.length === 0) {
      return response(400, { error: "Empty file" });
    }

    if (fileData.buffer.length > MAX_SIZE_BYTES) {
      return response(413, {
        error: "Payload Too Large",
        maxSize: MAX_SIZE_BYTES,
        actualSize: fileData.buffer.length,
      });
    }

    const detectedFormat = detectFormat(fileData.buffer);
    if (!detectedFormat || !ALLOWED_FORMATS.includes(detectedFormat)) {
      return response(415, {
        error: "Unsupported file format",
        allowed: ALLOWED_FORMATS,
        detected: detectedFormat || "unknown",
      });
    }

    const fileId = uuidv4();
    const extension = detectedFormat === "jpeg" ? "jpg" : detectedFormat;
    const s3Key = `${UPLOAD_PREFIX}${fileId}.${extension}`;

    await s3Client.send(
      new PutObjectCommand({
        Bucket: BUCKET,
        Key: s3Key,
        Body: fileData.buffer,
        ContentType: `image/${detectedFormat}`,
        Metadata: {
          "original-filename": fileData.filename || "unknown",
          "upload-id": fileId,
        },
      }),
    );

    console.log("File uploaded:", {
      bucket: BUCKET,
      key: s3Key,
      size: fileData.buffer.length,
    });

    return response(200, {
      success: true,
      fileId,
      key: s3Key,
      size: fileData.buffer.length,
      format: detectedFormat,
    });
  } catch (error) {
    console.error("Error processing upload:", error);
    return response(500, {
      error: "Internal Server Error",
      message: error.message,
    });
  }
};
