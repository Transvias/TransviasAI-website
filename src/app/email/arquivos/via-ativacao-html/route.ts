import { emailFileResponse } from "@/lib/email-file";

export const dynamic = "force-static";

export function GET() {
  return emailFileResponse("html");
}
