"use client";

import { useState, type FormEvent } from "react";
import { Button } from "@/components/ui/button";
import { Field, FieldError, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { fieldErrors, leadSchema, type LeadInput } from "@/lib/lead";

type FormValues = {
  transportadora: string;
  nome: string;
  sobrenome: string;
  ddd: string;
  whatsapp: string;
  website: string;
};

const inputClassName =
  "h-12 rounded-lg bg-white/5 px-3 text-base text-white placeholder:text-white/40 md:text-base";

function digitsOnly(value: string, maxLength: number) {
  return value.replace(/\D/g, "").slice(0, maxLength);
}

export function LeadForm({ transportadora }: { transportadora: string }) {
  const [values, setValues] = useState<FormValues>({
    transportadora,
    nome: "",
    sobrenome: "",
    ddd: "",
    whatsapp: "",
    website: "",
  });
  const [errors, setErrors] = useState<Partial<Record<keyof LeadInput, string>>>({});
  const [status, setStatus] = useState<"idle" | "submitting" | "success" | "error">("idle");
  const [formError, setFormError] = useState("");

  function update(field: keyof FormValues, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: undefined }));
  }

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const parsed = leadSchema.safeParse(values);

    if (!parsed.success) {
      setErrors(fieldErrors(parsed.error));
      setStatus("idle");
      return;
    }

    setStatus("submitting");
    setFormError("");

    try {
      const response = await fetch("/api/leads", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsed.data),
      });

      if (!response.ok) {
        setStatus("error");
        setFormError("Não foi possível enviar. Tente novamente.");
        return;
      }

      setStatus("success");
    } catch {
      setStatus("error");
      setFormError("Não foi possível enviar. Tente novamente.");
    }
  }

  if (status === "success") {
    return (
      <div className="w-full max-w-2xl rounded-2xl border border-primary/40 bg-primary/10 px-5 py-6" role="status">
        <h3 className="text-lg font-semibold">Recebemos seu interesse</h3>
        <p className="mt-2 text-base leading-relaxed text-foreground/80">
          A equipe do Transvias entra em contato pelo WhatsApp para ativar a ViA.
        </p>
      </div>
    );
  }

  return (
    <form className="relative flex w-full max-w-2xl flex-col gap-5" onSubmit={onSubmit} noValidate>
      <FieldGroup>
        <Field data-invalid={errors.transportadora ? true : undefined}>
          <FieldLabel htmlFor="transportadora">Transportadora</FieldLabel>
          <Input
            id="transportadora"
            name="transportadora"
            autoComplete="organization"
            value={values.transportadora}
            aria-invalid={Boolean(errors.transportadora)}
            className={inputClassName}
            onChange={(event) => update("transportadora", event.target.value)}
          />
          {!transportadora ? (
            <p className="text-sm text-foreground/70">
              Este link não trouxe o nome da transportadora. Preencha para continuar.
            </p>
          ) : null}
          <FieldError>{errors.transportadora}</FieldError>
        </Field>

        <Field data-invalid={errors.nome ? true : undefined}>
          <FieldLabel htmlFor="nome">Nome</FieldLabel>
          <Input
            id="nome"
            name="nome"
            autoComplete="given-name"
            value={values.nome}
            aria-invalid={Boolean(errors.nome)}
            className={inputClassName}
            onChange={(event) => update("nome", event.target.value)}
          />
          <FieldError>{errors.nome}</FieldError>
        </Field>

        <Field data-invalid={errors.sobrenome ? true : undefined}>
          <FieldLabel htmlFor="sobrenome">Sobrenome</FieldLabel>
          <Input
            id="sobrenome"
            name="sobrenome"
            autoComplete="family-name"
            value={values.sobrenome}
            aria-invalid={Boolean(errors.sobrenome)}
            className={inputClassName}
            onChange={(event) => update("sobrenome", event.target.value)}
          />
          <FieldError>{errors.sobrenome}</FieldError>
        </Field>

        <div className="grid grid-cols-[5.5rem_1fr] gap-3">
          <Field data-invalid={errors.ddd ? true : undefined}>
            <FieldLabel htmlFor="ddd">DDD</FieldLabel>
            <Input
              id="ddd"
              name="ddd"
              inputMode="numeric"
              autoComplete="tel-area-code"
              maxLength={2}
              value={values.ddd}
              aria-invalid={Boolean(errors.ddd)}
              className={inputClassName}
              onChange={(event) => update("ddd", digitsOnly(event.target.value, 2))}
            />
            <FieldError>{errors.ddd}</FieldError>
          </Field>

          <Field data-invalid={errors.whatsapp ? true : undefined}>
            <FieldLabel htmlFor="whatsapp">WhatsApp</FieldLabel>
            <Input
              id="whatsapp"
              name="whatsapp"
              inputMode="numeric"
              autoComplete="tel-local"
              maxLength={9}
              value={values.whatsapp}
              aria-invalid={Boolean(errors.whatsapp)}
              className={inputClassName}
              onChange={(event) => update("whatsapp", digitsOnly(event.target.value, 9))}
            />
            <FieldError>{errors.whatsapp}</FieldError>
          </Field>
        </div>
      </FieldGroup>

      <div className="absolute -left-[9999px] h-px w-px overflow-hidden" aria-hidden="true">
        <label htmlFor="website">Website</label>
        <input
          id="website"
          name="website"
          tabIndex={-1}
          autoComplete="off"
          value={values.website}
          onChange={(event) => update("website", event.target.value)}
        />
      </div>

      {formError ? (
        <p className="text-sm text-destructive" role="alert">
          {formError}
        </p>
      ) : null}

      <div className="relative mt-6">
        <span aria-hidden className="via-button-glow" />
        <Button
          type="submit"
          size="lg"
          className="relative h-12 w-full text-base font-semibold"
          disabled={status === "submitting"}
        >
          {status === "submitting" ? "Enviando..." : "Ativar a ViA"}
        </Button>
      </div>
    </form>
  );
}
