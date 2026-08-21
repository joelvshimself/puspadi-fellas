// supabase/functions/place-link/index.ts
//
// Shareable https link for a place — the URL the app's share sheet sends.
//
// Chat apps (WhatsApp included) only make http(s) URLs tappable, so the app
// cannot share `puspadifellas://…` directly. This function turns the tappable
// https link back into the app link with a 302: Safari follows it and asks to
// open the app (DeepLinkRouter handles the rest on iOS).
//
// A rendered HTML fallback page is NOT possible here: on the shared
// *.supabase.co domain the gateway rewrites text/html responses to text/plain
// (anti-phishing; custom domains only). Recipients without the app see
// Safari's "address is invalid" message — replace this with a Universal Links
// setup on a real domain when the project has one.
//
// GET /functions/v1/place-link?lat=-8.741&lng=115.178&name=Park23%20Mall&category=Mall
//
// Public by design (verify_jwt = false in config.toml): recipients of a shared
// link have no session. Redirects only to the app's own scheme, built from
// validated values — never to a caller-supplied URL.

const APP_SCHEME = "puspadifellas";

Deno.serve((req: Request) => {
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const params = new URL(req.url).searchParams;
  const lat = Number(params.get("lat"));
  const lng = Number(params.get("lng"));
  if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
      Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    return new Response("lat and lng are required", { status: 400 });
  }

  const name = (params.get("name") ?? "Shared place").slice(0, 120);
  const category = (params.get("category") ?? "").slice(0, 60);

  // encodeURIComponent, NOT URLSearchParams: the latter form-encodes spaces
  // as "+", which iOS's URLComponents leaves as a literal plus — the app
  // showed "Park23+Mall". %20 round-trips cleanly, and every value is
  // percent-encoded so nothing from the query can escape the scheme URL.
  const parts = [
    `lat=${lat}`,
    `lng=${lng}`,
    `name=${encodeURIComponent(name)}`,
  ];
  if (category) parts.push(`category=${encodeURIComponent(category)}`);
  const deepLink = `${APP_SCHEME}://place?${parts.join("&")}`;

  const headers = new Headers();
  headers.set("location", deepLink);
  // Same link, same redirect — let intermediaries cache it.
  headers.set("cache-control", "public, max-age=3600");
  return new Response(null, { status: 302, headers });
});
