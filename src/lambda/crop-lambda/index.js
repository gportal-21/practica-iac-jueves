const {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3Client = new S3Client({});

const BUCKET = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX || "processed/";

const OUTPUT_SIZE = 40;

async function streamToBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

async function cropCircular(inputBuffer) {
  const circleMask = Buffer.from(
    `<svg width="${OUTPUT_SIZE}" height="${OUTPUT_SIZE}">
       <circle cx="${OUTPUT_SIZE / 2}" cy="${OUTPUT_SIZE / 2}" r="${OUTPUT_SIZE / 2}" fill="white"/>
     </svg>`,
  );

  return await sharp(inputBuffer)
    .resize(OUTPUT_SIZE, OUTPUT_SIZE, {
      fit: "cover",
      position: "centre",
    })
    .composite([
      {
        input: circleMask,
        blend: "dest-in",
      },
    ])
    .png()
    .toBuffer();
}

async function processMessage(record) {
  const messageId = record.messageId;

  let s3Event;
  try {
    s3Event = JSON.parse(record.body);
  } catch (e) {
    throw new Error(`Invalid JSON in SQS body: ${e.message}`);
  }

  if (!s3Event.Records || !Array.isArray(s3Event.Records)) {
    if (s3Event.Event === "s3:TestEvent") {
      return;
    }
    throw new Error("SQS body does not contain S3 Records");
  }

  for (const s3Record of s3Event.Records) {
    const bucket = s3Record.s3.bucket.name;
    const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, " "));

    if (!key.startsWith("uploads/")) {
      console.log(`Skipping ${key} — not in uploads/ prefix`);
      continue;
    }

    const getResponse = await s3Client.send(
      new GetObjectCommand({ Bucket: bucket, Key: key }),
    );
    const inputBuffer = await streamToBuffer(getResponse.Body);

    const outputBuffer = await cropCircular(inputBuffer);

    const basename = key.replace(/^uploads\//, "").replace(/\.[^.]+$/, "");
    const outputKey = `${PROCESSED_PREFIX}${basename}_circular.png`;

    await s3Client.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: outputKey,
        Body: outputBuffer,
        ContentType: "image/png",
        Metadata: {
          "source-key": key,
          "processed-at": new Date().toISOString(),
        },
      }),
    );
  }
}

exports.handler = async (event) => {
  const batchItemFailures = [];

  const results = await Promise.allSettled(
    event.Records.map((record) => processMessage(record)),
  );

  results.forEach((result, index) => {
    if (result.status === "rejected") {
      const messageId = event.Records[index].messageId;
      batchItemFailures.push({ itemIdentifier: messageId });
    }
  });

  console.log(
    `Batch processed: ${results.length - batchItemFailures.length} succeeded, ${batchItemFailures.length} failed`,
  );

  return { batchItemFailures };
};
