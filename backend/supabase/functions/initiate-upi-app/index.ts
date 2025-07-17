import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Use environment variables for production credentials
const merchantId =  "JP2000000000554";
const merchantKey = "1a5c73f115e24414a84d82e9b487e3b0";

async function generateSecureHash(params: Record<string, any>, key: string): Promise<string> {
  const filtered = Object.entries(params).filter(([_, v]) => v !== "" && v !== undefined && v !== null);
  filtered.sort(([a], [b]) => a.localeCompare(b));
  const concatenatedValues = filtered.map(([_, v]) => v).join("");
  const encoder = new TextEncoder();
  const keyBytes = encoder.encode(key);
  const data = encoder.encode(concatenatedValues);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, data);
  return Array.from(new Uint8Array(signature)).map(b => b.toString(16).padStart(2, '0')).join("").toLowerCase();
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { amount, merchantRefNo, mobileNo, emailID, invoiceNo, invoiceDate, customerID } = body;
  if (!amount || !merchantRefNo || !mobileNo || !emailID || !invoiceNo || !invoiceDate) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const params = {
    merchantId,
    merchantRefNo,
    amount,
    currency: "356",
    mobileNo,
    emailID,
    invoiceNo,
    requestType: "UPIQR",
    customerID: customerID ?? "",
    invoiceDate,
  };
  params["secureHash"] = await generateSecureHash(params, merchantKey);

  // Prepare x-www-form-urlencoded body
  const formBody = Object.entries(params)
    .map(([k, v]) => encodeURIComponent(k) + "=" + encodeURIComponent(v))
    .join("&");

  // Use production endpoint
  const qrRes = await fetch("https://jiopay.co.in/pg/api/generateQR", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: formBody,
  });
  const qrData = await qrRes.json();
  return new Response(JSON.stringify(qrData), {
    headers: { "Content-Type": "application/json" },
  });
}); 