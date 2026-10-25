import { betterAuth } from "better-auth";
import { bearer } from "better-auth/plugins";
import { importPKCS8, SignJWT } from "jose";
import type { Env } from "./env";
import { HttpError } from "./http";

async function appleClientSecret(env: Env): Promise<string> {
  const privateKey = env.APPLE_PRIVATE_KEY.replaceAll("\\n", "\n");
  const key = await importPKCS8(privateKey, "ES256");
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setSubject(env.APPLE_CLIENT_ID)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt(now)
    .setExpirationTime(now + 60 * 60 * 24 * 180)
    .sign(key);
}

/**
 * Sign-in is Apple and Google only, from the phones' native buttons, which hand us an ID token.
 * Checking an Apple ID token needs only the bundle ID; the private key (client secret) matters only
 * for web flows, so Apple works without it. Google accepts ID tokens minted for any of our client IDs
 * (web, iOS, Android) and is enabled once one is set.
 */
function socialProviders(env: Env) {
  const googleClientIds = [env.GOOGLE_WEB_CLIENT_ID, env.GOOGLE_IOS_CLIENT_ID, env.GOOGLE_ANDROID_CLIENT_ID]
    .filter((id): id is string => Boolean(id) && !id!.startsWith("replace-with"));
  return {
    apple: async () => ({
      clientId: env.APPLE_CLIENT_ID,
      appBundleIdentifier: env.APPLE_CLIENT_ID,
      clientSecret: env.APPLE_PRIVATE_KEY && env.APPLE_KEY_ID && env.APPLE_TEAM_ID ? await appleClientSecret(env) : "",
    }),
    ...(googleClientIds.length ? {
      google: { clientId: googleClientIds, clientSecret: env.GOOGLE_CLIENT_SECRET ?? "" },
    } : {}),
  };
}

export function createAuth(env: Env) {
  return betterAuth({
    appName: "Rollspot",
    baseURL: env.API_BASE_URL,
    basePath: "/api/auth",
    secret: env.BETTER_AUTH_SECRET,
    database: env.DB,
    trustedOrigins: ["puspadi://", "puspadifellas://", "https://appleid.apple.com"],
    socialProviders: socialProviders(env),
    plugins: [bearer({ requireSignature: true })],
    advanced: {
      cookiePrefix: "rollspot",
      useSecureCookies: true,
      database: { generateId: () => crypto.randomUUID() },
    },
  });
}

export type Auth = ReturnType<typeof createAuth>;

/**
 * Without BETTER_AUTH_SECRET, Better Auth falls back to a public default secret. Refuse instead,
 * so a missing `wrangler secret put` shows up as a clear error rather than weak sessions.
 */
export function assertAuthConfigured(auth: Auth) {
  if (!auth.options.secret) {
    throw new HttpError(503, "Sign in isn't available yet: the server has no BETTER_AUTH_SECRET.", "auth_not_configured");
  }
}

export async function requireUserId(auth: Auth, request: Request): Promise<string> {
  assertAuthConfigured(auth);
  const result = await auth.api.getSession({ headers: request.headers });
  if (!result?.user?.id) {
    const error = new Error("Sign in is required.") as Error & { status?: number };
    error.status = 401;
    throw error;
  }
  return result.user.id;
}
