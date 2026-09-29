import { z } from "zod";

export const leadSchema = z.object({
  transportadora: z
    .string()
    .trim()
    .min(1, "Informe a transportadora.")
    .max(120, "O nome da transportadora está longo demais."),
  nome: z.string().trim().min(1, "Informe o nome.").max(80, "O nome está longo demais."),
  sobrenome: z
    .string()
    .trim()
    .min(1, "Informe o sobrenome.")
    .max(80, "O sobrenome está longo demais."),
  ddd: z.string().regex(/^\d{2}$/, "O DDD deve ter 2 dígitos."),
  whatsapp: z.string().regex(/^\d{8,9}$/, "Informe 8 ou 9 dígitos, sem o DDD."),
  website: z.string().optional(),
});

export type LeadInput = z.infer<typeof leadSchema>;

export function fieldErrors(error: z.ZodError<LeadInput>) {
  const errors: Partial<Record<keyof LeadInput, string>> = {};

  for (const issue of error.issues) {
    const key = issue.path[0];
    if (typeof key === "string" && !errors[key as keyof LeadInput]) {
      errors[key as keyof LeadInput] = issue.message;
    }
  }

  return errors;
}
