import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions";
const MODEL = "gemini-3.8-flash";

const ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"] as const;

/// Free-tier scans per day, resetting at the client's local midnight (the
/// client sends today's date key; this is just the authoritative counter).
const FREE_SCAN_LIMIT = 3;

/** Thrown to short-circuit a handler with a message written back to Firestore. */
class AppError extends Error {}

/** Thrown when the account has hit its daily free-scan quota. */
class QuotaExceededError extends Error {}

/**
 * Authoritative server-side check for the free-tier daily scan limit — the
 * client also keeps its own counter (for instant "scans left" UI), but that
 * alone is trivially bypassable, so this transaction is what actually
 * decides whether Gemini gets called. Pro accounts and requests with no
 * `userId` (shouldn't happen now every device gets an anonymous Firebase
 * identity, but keeps this from breaking older clients) are not gated here.
 */
async function checkAndConsumeScanQuota(userId: string, scanDateKey: string): Promise<void> {
  const userRef = getFirestore().collection("users").doc(userId);
  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() ?? {};
    if (data.isPro === true) return;

    const sameDay = data.scanDateKey === scanDateKey;
    const usedToday = sameDay ? ((data.scansUsedToday as number) ?? 0) : 0;
    if (usedToday >= FREE_SCAN_LIMIT) {
      throw new QuotaExceededError("You've reached today's free scan limit. Upgrade to Pro for unlimited scans.");
    }
    tx.set(userRef, { scansUsedToday: usedToday + 1, scanDateKey }, { merge: true });
  });
}

const PAINTING_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string", description: "The painting's title. Use 'Untitled' if unknown." },
    artist: { type: "string", description: "The artist's name. Use 'Unknown' if not identifiable." },
    year: {
      type: "string",
      description: "Year or era created, e.g. '1889' or 'c. 1665'. Use 'Unknown' if not identifiable.",
    },
    movement: { type: "string", description: "Art movement or style, e.g. 'Post-Impressionism'." },
    museum: { type: "string", description: "Museum or collection that holds the work, or '—' if unknown." },
    confidence: {
      type: "integer",
      minimum: 0,
      maximum: 100,
      description:
        "Confidence (0-100) that the identification is correct. Use a low value (under 60) if you cannot " +
        "confidently identify the specific work.",
    },
    hook: { type: "string", description: "A single punchy one-sentence hook about the painting." },
    stories: {
      type: "object",
      description:
        "The painting's story told at three depths. Kid and Simple each need both a short (free-tier) and " +
        "full (Pro) version; Art-lover is Pro-only so only needs the full version.",
      properties: {
        kidShort: { type: "string", description: "1-2 simple, playful sentences for a child (free-tier length)." },
        kid: { type: "string", description: "3-5 simple, playful sentences for a child (full version)." },
        simpleShort: {
          type: "string",
          description: "A short, 2-3 sentence accessible summary for a general adult audience (free-tier length).",
        },
        simple: { type: "string", description: "A full, accessible paragraph for a general adult audience." },
        artLover: { type: "string", description: "A richer, more technical paragraph for an art enthusiast." },
      },
      required: ["kidShort", "kid", "simpleShort", "simple", "artLover"],
    },
    details: {
      type: "array",
      description:
        "2-5 interesting hidden details/hotspots found in the painting, positioned as fractional " +
        "coordinates over the image.",
      items: {
        type: "object",
        properties: {
          x: { type: "number", minimum: 0, maximum: 1, description: "Fractional horizontal position (0-1)." },
          y: { type: "number", minimum: 0, maximum: 1, description: "Fractional vertical position (0-1)." },
          title: { type: "string", description: "Short title for this detail." },
          description: { type: "string", description: "1-2 sentences explaining this detail." },
          locked: {
            type: "boolean",
            description: "Whether this detail should be Pro-only (lock roughly half when there are 3+).",
          },
        },
        required: ["x", "y", "title", "description", "locked"],
      },
    },
  },
  required: ["title", "artist", "year", "movement", "museum", "confidence", "hook", "stories", "details"],
};

const IDENTIFY_SYSTEM_PROMPT =
  "You are an expert art historian helping a museum-goer identify a painting from a photo they just took. " +
  "Examine the image and identify the painting if you recognize it. If you cannot confidently identify the " +
  "specific work, still describe what you can observe (style, subject, technique, likely era) and report a " +
  "low confidence score rather than guessing a specific title. Always respond with the requested JSON fields.";

interface GeminiStep {
  type: string;
  content?: Array<{ type: string; text?: string }>;
}

interface GeminiInteractionResponse {
  id?: string;
  steps?: GeminiStep[];
}

async function callGemini(body: Record<string, unknown>): Promise<GeminiInteractionResponse> {
  let response: Response;
  try {
    response = await fetch(GEMINI_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiApiKey.value() },
      body: JSON.stringify(body),
    });
  } catch {
    throw new AppError("Could not reach the AI backend — check your connection and try again.");
  }

  if (!response.ok) {
    switch (response.status) {
      case 400:
        throw new AppError("The AI backend rejected the request.");
      case 403:
        throw new AppError("The AI backend key doesn't have access.");
      case 429:
        throw new AppError("Too many requests right now — please try again shortly.");
      default:
        throw new AppError("Couldn't reach the AI backend — please try again.");
    }
  }

  return (await response.json()) as GeminiInteractionResponse;
}

function extractText(response: GeminiInteractionResponse): string {
  const steps = response.steps ?? [];
  const modelOutput = [...steps].reverse().find((step) => step.type === "model_output");
  const textBlock = modelOutput?.content?.find((block) => block.type === "text");
  const text = textBlock?.text;
  if (!text) {
    throw new AppError("The AI backend returned an unexpected response.");
  }
  return text;
}

interface PaintingSummary {
  title: string;
  artist: string;
  year: string;
  movement: string;
  museum: string;
  stories?: Record<string, string>;
  details?: Array<{ title?: string; description?: string }>;
}

function chatSystemPromptFor(painting: PaintingSummary): string {
  const details = painting.details ?? [];
  const detailLines = details.map((d) => `- ${d.title ?? ""}: ${d.description ?? ""}`).join("\n");
  const summary = painting.stories?.["Art-lover"] || painting.stories?.["Simple"] || "";
  return (
    "You are an expert art historian chatting with a museum-goer about a specific painting they just " +
    "identified with this app. Answer their questions conversationally in 2-4 sentences, no markdown " +
    "formatting. Stay grounded in the facts below; if something isn't covered by them and you're not " +
    "confident, say so honestly rather than inventing details.\n\n" +
    `Painting: ${painting.title}\n` +
    `Artist: ${painting.artist}\n` +
    `Year: ${painting.year}\n` +
    `Movement: ${painting.movement}\n` +
    `Museum: ${painting.museum}\n` +
    `Summary: ${summary}\n` +
    (detailLines ? `Known hidden details:\n${detailLines}` : "")
  );
}

/**
 * These functions are triggered by a Firestore document write rather than an
 * HTTP request. The client creates a "pending" doc; this function fills in
 * the result (or error) on that same doc, which the client is listening to.
 * This sidesteps needing a publicly-invokable HTTP endpoint entirely, which
 * this project's org policy (Domain Restricted Sharing) blocks — Firestore
 * triggers run via Google-internal Eventarc/Pub-Sub service identities that
 * are scoped to this project, not `allUsers`.
 */
export const onIdentifyRequestCreated = onDocumentCreated(
  { document: "identifyRequests/{requestId}", secrets: [geminiApiKey], timeoutSeconds: 60, memory: "512MiB" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ref = snap.ref;
    const data = snap.data();

    try {
      const imageBase64 = data.imageBase64;
      const mimeType = data.mimeType;
      const userId = data.userId;
      const scanDateKey = data.scanDateKey;

      if (!imageBase64 || typeof imageBase64 !== "string") {
        throw new AppError("imageBase64 is required.");
      }
      if (!mimeType || typeof mimeType !== "string" || !(ALLOWED_MIME_TYPES as readonly string[]).includes(mimeType)) {
        throw new AppError("A supported mimeType is required.");
      }
      if (imageBase64.length > 900_000) {
        throw new AppError("Image is too large.");
      }

      if (typeof userId === "string" && userId && typeof scanDateKey === "string" && scanDateKey) {
        await checkAndConsumeScanQuota(userId, scanDateKey);
      }

      const response = await callGemini({
        model: MODEL,
        system_instruction: IDENTIFY_SYSTEM_PROMPT,
        input: [
          { type: "image", data: imageBase64, mime_type: mimeType },
          { type: "text", text: "Identify this painting." },
        ],
        response_format: { type: "text", mime_type: "application/json", schema: PAINTING_SCHEMA },
      });

      const text = extractText(response);
      let result: Record<string, unknown>;
      try {
        result = JSON.parse(text);
      } catch {
        throw new AppError("The AI backend returned an unexpected response.");
      }

      const stories = (result.stories as Record<string, string>) ?? {};
      const details = (result.details as Array<Record<string, unknown>>) ?? [];

      await ref.update({
        status: "complete",
        result: {
          title: (result.title as string) || "Untitled",
          artist: (result.artist as string) || "Unknown",
          year: (result.year as string) || "Unknown",
          movement: (result.movement as string) || "Unknown",
          museum: (result.museum as string) || "—",
          confidence: Math.max(0, Math.min(100, Math.round((result.confidence as number) ?? 0))),
          hook: (result.hook as string) || "",
          stories: {
            Kid: stories.kid || "",
            Simple: stories.simple || "",
            "Art-lover": stories.artLover || "",
          },
          shortStories: {
            Kid: stories.kidShort || stories.kid || "",
            Simple: stories.simpleShort || stories.simple || "",
          },
          details: details.map((d) => ({
            x: d.x,
            y: d.y,
            title: d.title || "",
            description: d.description || "",
            locked: Boolean(d.locked),
          })),
        },
      });
    } catch (error) {
      if (error instanceof QuotaExceededError) {
        await ref.update({ status: "quota_exceeded", error: error.message });
        return;
      }
      const message = error instanceof AppError ? error.message : "Couldn't identify the painting — please try again.";
      if (!(error instanceof AppError)) console.error(error);
      await ref.update({ status: "error", error: message });
    }
  }
);

export const onChatRequestCreated = onDocumentCreated(
  { document: "chatRequests/{requestId}", secrets: [geminiApiKey], timeoutSeconds: 30, memory: "256MiB" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ref = snap.ref;
    const data = snap.data();

    try {
      const painting = data.painting as PaintingSummary | undefined;
      const question = data.question;
      const previousInteractionId = data.previousInteractionId;

      if (!painting || typeof painting !== "object") {
        throw new AppError("painting is required.");
      }
      if (!question || typeof question !== "string" || question.trim().length === 0) {
        throw new AppError("question is required.");
      }

      const response = await callGemini({
        model: MODEL,
        system_instruction: chatSystemPromptFor(painting),
        input: question,
        ...(typeof previousInteractionId === "string" ? { previous_interaction_id: previousInteractionId } : {}),
      });

      const answer = extractText(response);
      const id = response.id;
      if (!id) {
        throw new AppError("The AI backend returned an unexpected response.");
      }

      await ref.update({ status: "complete", answer, interactionId: id });
    } catch (error) {
      const message = error instanceof AppError ? error.message : "Couldn't get an answer — please try again.";
      if (!(error instanceof AppError)) console.error(error);
      await ref.update({ status: "error", error: message });
    }
  }
);
