export interface Env {
  DB: D1Database;
  MEDIA: R2Bucket;
  API_BASE_URL: string;
  BETTER_AUTH_SECRET: string;
  APPLE_CLIENT_ID: string;
  APPLE_TEAM_ID: string;
  APPLE_KEY_ID: string;
  APPLE_PRIVATE_KEY: string;
  GOOGLE_IOS_CLIENT_ID: string;
  GOOGLE_ANDROID_CLIENT_ID?: string;
  GOOGLE_WEB_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  EMAIL_FROM: string;
  RESEND_API_KEY: string;
  /** Firebase service account JSON for push notifications (src/push.ts). Push is off without it. */
  FCM_SERVICE_ACCOUNT?: string;
  /** Bearer token for /v1/admin/* endpoints. */
  ADMIN_TOKEN?: string;
}
