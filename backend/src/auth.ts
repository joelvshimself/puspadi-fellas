import { betterAuth } from "better-auth";
import { bearer } from "better-auth/plugins";
import { importPKCS8, SignJWT } from "jose";
import type { Env } from "./env";

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

async function sendEmail(env: Env, to: string, subject: string, html: string): Promise<void> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ from: env.EMAIL_FROM, to: [to], subject, html }),
  });
  if (!response.ok) throw new Error(`Email delivery failed with status ${response.status}.`);
}

export function createAuth(env: Env) {
  return betterAuth({
    appName: "Rollspot",
    baseURL: env.API_BASE_URL,
    basePath: "/api/auth",
    secret: env.BETTER_AUTH_SECRET,
    database: env.DB,
    trustedOrigins: ["puspadi://", "puspadifellas://", "https://appleid.apple.com"],
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      sendResetPassword: async ({ user, url }) => {
        await sendEmail(
          env,
          user.email,
          "Reset your Rollspot password",
          `<p>Use this secure link to reset your Rollspot password:</p><p><a href="${url}">Reset password</a></p>`,
        );
      },
    },
    emailVerification: {
      sendOnSignUp: true,
      autoSignInAfterVerification: false,
      sendVerificationEmail: async ({ user, url }) => {
        await sendEmail(
          env,
          user.email,
          "Confirm your Rollspot email",
          `<p>Confirm your email to finish creating your Rollspot account:</p><p><a href="${url}">Confirm email</a></p>`,
        );
      },
    },
    socialProviders: {
      apple: async () => ({
        clientId: env.APPLE_CLIENT_ID,
        appBundleIdentifier: env.APPLE_CLIENT_ID,
        clientSecret: await appleClientSecret(env),
      }),
      google: {
        clientId: [env.GOOGLE_WEB_CLIENT_ID, env.GOOGLE_IOS_CLIENT_ID],
        clientSecret: env.GOOGLE_CLIENT_SECRET,
      },
    },
    plugins: [bearer({ requireSignature: true })],
    advanced: {
      cookiePrefix: "rollspot",
      useSecureCookies: true,
      database: { generateId: () => crypto.randomUUID() },
    },
  });
}

export type Auth = ReturnType<typeof createAuth>;

export async function requireUserId(auth: Auth, request: Request): Promise<string> {
  const result = await auth.api.getSession({ headers: request.headers });
  if (!result?.user?.id) {
    const error = new Error("Sign in is required.") as Error & { status?: number };
    error.status = 401;
    throw error;
  }
  return result.user.id;
}
