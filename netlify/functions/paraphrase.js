const requests = new Map();
const WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_REQUESTS = 20;

const MODE_INSTRUCTIONS = {
  standard: "Naturally rewrite the text while preserving its exact meaning and important details.",
  fluency:  "Improve grammar, readability, sentence flow, vocabulary and naturalness while preserving the original meaning.",
  formal:   "Rewrite the text in a professional, formal, polished and appropriate style while preserving the original meaning.",
  simple:   "Rewrite the text using simple, clear, easy-to-understand language while preserving the original meaning.",
  creative: "Rewrite the text in an engaging, natural, varied and expressive style while preserving the original meaning."
};

function getClientIP(event) {
  const headers = event.headers || {};
  const forwarded = headers["x-forwarded-for"] || headers["x-nf-client-connection-ip"];
  if (forwarded) return forwarded.split(",")[0].trim();
  return "unknown";
}

function checkRateLimit(ip) {
  const now = Date.now();
  const existing = requests.get(ip);
  if (!existing || now - existing.start > WINDOW_MS) {
    requests.set(ip, { start: now, count: 1 });
    return { allowed: true, remaining: MAX_REQUESTS - 1 };
  }
  if (existing.count >= MAX_REQUESTS) {
    return { allowed: false, remaining: 0, retryAfter: Math.ceil((WINDOW_MS - (now - existing.start)) / 1000) };
  }
  existing.count++;
  return { allowed: true, remaining: MAX_REQUESTS - existing.count };
}

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method Not Allowed" };
  }

  const GROQ_KEY = process.env.GROQ_API_KEY;
  if (!GROQ_KEY) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "API key not configured." }) };
  }

  const ip = getClientIP(event);
  const rateLimit = checkRateLimit(ip);

  if (!rateLimit.allowed) {
    return {
      statusCode: 429,
      headers: { "Content-Type": "application/json", "Retry-After": String(rateLimit.retryAfter) },
      body: JSON.stringify({ error: "Too many requests. Please try again in an hour." })
    };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Invalid request." }) };
  }

  const { text, mode = "standard", language = "English" } = body;

  if (!text || typeof text !== "string" || !text.trim()) {
    return { statusCode: 400, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Please enter some text." }) };
  }
  if (text.trim().length > 2000) {
    return { statusCode: 400, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Maximum 2,000 characters allowed per request." }) };
  }

  const instruction = MODE_INSTRUCTIONS[mode] || MODE_INSTRUCTIONS.standard;

  const prompt = `You are an expert multilingual paraphrasing assistant.

Your task is to paraphrase the user's text.

STYLE:
${instruction}

OUTPUT LANGUAGE:
${language}

IMPORTANT RULES:
- Preserve the original meaning.
- Do not invent facts or add unsupported information.
- Do not remove important information.
- Do not summarize unless the original text itself is a summary.
- Do not explain your changes or mention you are an AI.
- Do not put the answer inside quotation marks.
- Return ONLY the paraphrased text.
- Keep approximately the same level of detail.
- Make the result natural and readable.

TEXT TO PARAPHRASE:

${text.trim()}`;

  try {
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + GROQ_KEY },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: "You are a professional multilingual paraphrasing assistant." },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 2500
      })
    });

    const data = await response.json();

    if (!response.ok) {
      return { statusCode: 502, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "AI service temporarily unavailable." }) };
    }

    const paraphrased = data?.choices?.[0]?.message?.content?.trim();
    if (!paraphrased) {
      return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "No result generated. Please try again." }) };
    }

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ paraphrased, remainingRequests: rateLimit.remaining })
    };

  } catch (err) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Something went wrong. Please try again." }) };
  }
};
