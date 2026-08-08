"use client";

import { useEffect, useState } from "react";
import {
  Bot,
  BrainCircuit,
  Cloud,
  Info,
  Loader2,
  LockKeyhole,
  ShieldCheck,
  Sparkles,
  WalletCards,
} from "lucide-react";
import { useTranslations } from "next-intl";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useUpdateSettings, type UserSettings } from "@/hooks/use-settings";
import { cn } from "@/lib/utils";

export function AiConsentDialog({
  open,
  onOpenChange,
  onEnabled,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onEnabled?: (settings: UserSettings) => void;
}) {
  const t = useTranslations("ai");
  const update = useUpdateSettings();
  const [confirmed, setConfirmed] = useState(false);

  useEffect(() => {
    if (!open) setConfirmed(false);
  }, [open]);

  const enable = () => {
    if (!confirmed) return;
    update.mutate(
      { aiEnabled: true, aiConsentConfirmed: true },
      {
        onSuccess: (settings) => {
          toast.success(t("consentEnabled"));
          onEnabled?.(settings);
          onOpenChange(false);
        },
        onError: (error: any) => toast.error(error?.message),
      },
    );
  };

  const points = [
    {
      icon: WalletCards,
      title: t("consentDataTitle"),
      body: t("consentDataBody"),
    },
    {
      icon: Cloud,
      title: t("consentProviderTitle"),
      body: t("consentProviderBody"),
    },
    {
      icon: ShieldCheck,
      title: t("consentControlTitle"),
      body: t("consentControlBody"),
    },
  ];

  return (
    <Dialog
      open={open}
      onOpenChange={(value) => !update.isPending && onOpenChange(value)}
    >
      <DialogContent className="max-w-xl gap-5 p-5 sm:p-6">
        <DialogHeader className="items-center text-center">
          <span className="mb-2 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-primary to-violet-600 text-white shadow-lg shadow-primary/20">
            <BrainCircuit className="h-7 w-7" />
          </span>
          <DialogTitle className="text-xl font-bold">
            {t("consentTitle")}
          </DialogTitle>
          <DialogDescription className="max-w-md leading-relaxed">
            {t("consentIntro")}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          {points.map(({ icon: Icon, title, body }) => (
            <div
              key={title}
              className="flex gap-3 rounded-xl border border-border bg-muted/25 p-3"
            >
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                <Icon className="h-4 w-4" />
              </span>
              <div>
                <p className="text-sm font-semibold text-foreground">{title}</p>
                <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">
                  {body}
                </p>
              </div>
            </div>
          ))}
        </div>

        <div className="flex gap-2.5 rounded-xl border border-amber-500/25 bg-amber-500/10 p-3 text-xs leading-relaxed text-foreground">
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-amber-600 dark:text-amber-400" />
          <p>{t("consentAccuracy")}</p>
        </div>

        <label
          className={cn(
            "flex cursor-pointer items-start gap-3 rounded-xl border p-3.5 transition-colors",
            confirmed
              ? "border-primary/40 bg-primary/5"
              : "border-border bg-card",
          )}
        >
          <input
            type="checkbox"
            checked={confirmed}
            disabled={update.isPending}
            onChange={(event) => setConfirmed(event.target.checked)}
            className="mt-0.5 h-4 w-4 rounded border-border accent-primary"
          />
          <span className="text-xs leading-relaxed text-foreground">
            {t("consentCheckbox")}
          </span>
        </label>

        <DialogFooter className="sm:grid sm:grid-cols-2">
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={update.isPending}
          >
            {t("consentNotNow")}
          </Button>
          <Button onClick={enable} disabled={!confirmed || update.isPending}>
            {update.isPending ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Sparkles className="h-4 w-4" />
            )}
            {t("enableAction")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function AiDisabledState({ compact = false }: { compact?: boolean }) {
  const t = useTranslations("ai");
  const [open, setOpen] = useState(false);

  const content = (
    <CardContent
      className={cn(
        "flex flex-col items-center text-center",
        compact ? "p-5" : "p-8",
      )}
    >
      <span
        className={cn(
          "relative flex items-center justify-center rounded-2xl bg-primary/10 text-primary",
          compact ? "h-11 w-11" : "h-16 w-16",
        )}
      >
        <Bot className={compact ? "h-5 w-5" : "h-8 w-8"} />
        <span className="absolute -bottom-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full border-2 border-card bg-muted text-muted-foreground">
          <LockKeyhole className="h-2.5 w-2.5" />
        </span>
      </span>
      <h2
        className={cn(
          "font-bold text-foreground",
          compact ? "mt-3 text-base" : "mt-5 text-xl",
        )}
      >
        {t("disabledTitle")}
      </h2>
      <p
        className={cn(
          "max-w-lg leading-relaxed text-muted-foreground",
          compact ? "mt-1 text-xs" : "mt-2 text-sm",
        )}
      >
        {t("disabledBody")}
      </p>
      <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-emerald-500/10 px-2.5 py-1 text-[11px] font-medium text-emerald-700 dark:text-emerald-400">
        <ShieldCheck className="h-3 w-3" /> {t("offBadge")}
      </div>
      <Button
        className={compact ? "mt-4" : "mt-6"}
        onClick={() => setOpen(true)}
      >
        <ShieldCheck className="h-4 w-4" /> {t("enableAction")}
      </Button>
    </CardContent>
  );

  return (
    <>
      <Card
        className={cn(
          !compact && "mx-auto max-w-2xl border-primary/15 shadow-sm",
        )}
      >
        {content}
      </Card>
      <AiConsentDialog open={open} onOpenChange={setOpen} />
    </>
  );
}
