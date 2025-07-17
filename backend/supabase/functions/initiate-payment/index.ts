import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const merchantId = "JP2000000000554";
const merchantKey = "1a5c73f115e24414a84d82e9b487e3b0"; // Store securely in env for prod

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
  const { amount, customerEmailID } = body;
  if (!amount || !customerEmailID) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const merchantTxnNo = `Txn${Date.now()}`;
  const txnDate = new Date().toISOString().replace(/[-:.TZ]/g, '').substring(0, 14);
  const returnUrl = "https://jiopay.co.in/pg/api/v2/initiateSale";
  const payload = {
    merchantId,
    merchantTxnNo,
    amount,
    currencyCode: "356",
    payType: "0",
    customerEmailID,
    transactionType: "SALE",
    returnURL: returnUrl,
    txnDate,
  };
  payload["secureHash"] = await generateSecureHash(payload, merchantKey);
  const jiopayRes = await fetch("https://jiopay.co.in/pg/api/v2/initiateSale", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const jiopayData = await jiopayRes.json();
  return new Response(JSON.stringify({ ...jiopayData, merchantTxnNo }), {
    headers: { "Content-Type": "application/json" },
  });
}); 