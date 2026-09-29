import { Resend } from "resend";
import { leadSchema } from "@/lib/lead";

const genericError = "Não foi possível enviar. Tente novamente.";

export async function POST(request: Request) {
  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return Response.json({ error: genericError }, { status: 400 });
  }

  const parsed = leadSchema.safeParse(body);

  if (!parsed.success) {
    return Response.json({ error: "Revise os campos e tente novamente." }, { status: 400 });
  }

  if (parsed.data.website) {
    return Response.json({ ok: true });
  }

  const apiKey = process.env.RESEND_API_KEY;
  const to = process.env.LEAD_EMAIL_TO;
  const from = process.env.LEAD_EMAIL_FROM;

  if (!apiKey || !to || !from) {
    console.error("Lead email is not configured.");
    return Response.json({ error: genericError }, { status: 500 });
  }

  const { transportadora, nome, sobrenome, ddd, whatsapp } = parsed.data;
  const subject = `Novo lead ViA: ${transportadora.replace(/[\r\n]+/g, " ").slice(0, 120)}`;
  const resend = new Resend(apiKey);
  const { error } = await resend.emails.send({
    from,
    to,
    subject,
    text: [
      "Novo interesse na ViA",
      "",
      `Transportadora: ${transportadora}`,
      `Nome: ${nome} ${sobrenome}`,
      `WhatsApp: (${ddd}) ${whatsapp}`,
    ].join("\n"),
  });

  if (error) {
    console.error("Resend rejected the lead email.");
    return Response.json({ error: genericError }, { status: 500 });
  }

  return Response.json({ ok: true });
}
