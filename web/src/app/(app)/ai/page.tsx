"use client";

import { useState } from "react";
import { BarChart3, MessagesSquare, Sparkles, TrendingUp } from "lucide-react";
import { useTranslations } from "next-intl";
import { cn } from "@/lib/utils";
import { ChatPanel } from "@/components/ai/chat-panel";
import { ForecastTab } from "@/components/ai/forecast-tab";
import { MonthAnalysisTab } from "@/components/ai/month-analysis-tab";
import { AiDisabledState } from "@/components/ai/ai-access";
import { Skeleton } from "@/components/ui/skeleton";
import { useUserSettings } from "@/hooks/use-settings";

export default function AiPage() {
  const t = useTranslations("ai");
  const [tab, setTab] = useState<"discussion" | "forecast" | "analysis">(
    "discussion",
  );
  const { data: settings, isLoading } = useUserSettings();

  const tabs = [
    {
      id: "discussion" as const,
      label: t("tabDiscussion"),
      icon: MessagesSquare,
    },
    { id: "forecast" as const, label: t("tabForecast"), icon: TrendingUp },
    { id: "analysis" as const, label: t("tabAnalysis"), icon: BarChart3 },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-2">
        <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10">
          <Sparkles className="h-5 w-5 text-primary" />
        </span>
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">
            {t("title")}
          </h1>
          <p className="text-sm text-muted-foreground">{t("headerSubtitle")}</p>
        </div>
      </div>

      {isLoading ? (
        <Skeleton className="h-72 rounded-xl" />
      ) : settings?.aiEnabled !== true ? (
        <AiDisabledState />
      ) : (
        <>
          {/* Tabs */}
          <div className="flex gap-1 overflow-x-auto border-b border-border">
            {tabs.map((tb) => {
              const Icon = tb.icon;
              const active = tab === tb.id;
              return (
                <button
                  key={tb.id}
                  onClick={() => setTab(tb.id)}
                  className={cn(
                    "flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors",
                    active
                      ? "border-primary text-primary"
                      : "border-transparent text-muted-foreground hover:text-foreground",
                  )}
                >
                  <Icon className="h-4 w-4" />
                  {tb.label}
                </button>
              );
            })}
          </div>

          {tab === "discussion" && <ChatPanel />}
          {tab === "forecast" && <ForecastTab />}
          {tab === "analysis" && <MonthAnalysisTab />}
        </>
      )}
    </div>
  );
}
