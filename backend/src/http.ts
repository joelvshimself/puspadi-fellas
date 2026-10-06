export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("content-type", "application/json; charset=utf-8");
  responseHeaders.set("cache-control", "no-store");
  return new Response(JSON.stringify(body), { status, headers: responseHeaders });
}

export async function readJson<T>(request: Request): Promise<T> {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    throw new HttpError(415, "A JSON request body is required.");
  }
  try {
    return await request.json() as T;
  } catch {
    throw new HttpError(400, "The request body is not valid JSON.");
  }
}

export function methodNotAllowed(...methods: string[]): Response {
  return json(
    { error: "method_not_allowed", message: "Method not allowed." },
    405,
    { allow: methods.join(", ") },
  );
}

export function requiredString(value: unknown, field: string, max = 500): string {
  if (typeof value !== "string") throw new HttpError(400, `${field} is required.`);
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > max) throw new HttpError(400, `${field} is invalid.`);
  return trimmed;
}

export function uuid(): string {
  return crypto.randomUUID();
}
