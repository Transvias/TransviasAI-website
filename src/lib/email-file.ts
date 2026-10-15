import { readFile } from "node:fs/promises";
import path from "node:path";

const emailFiles = {
  html: {
    filename: "via-ativacao.html",
    type: "text/html; charset=utf-8",
  },
  txt: {
    filename: "via-ativacao.txt",
    type: "text/plain; charset=utf-8",
  },
} as const;

export async function emailFileResponse(kind: keyof typeof emailFiles) {
  const file = emailFiles[kind];
  const body = await readFile(path.join(process.cwd(), "emails", file.filename));

  return new Response(body, {
    headers: {
      "Content-Type": file.type,
      "Content-Disposition": `attachment; filename="${file.filename}"`,
    },
  });
}
