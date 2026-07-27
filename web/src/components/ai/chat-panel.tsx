'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import {
  Bot,
  Check,
  Copy,
  Eraser,
  Lightbulb,
  Loader2,
  Send,
  SlidersHorizontal,
  Sparkles,
  ThumbsDown,
  ThumbsUp,
  User,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { MarkdownMessage } from '@/components/ai/markdown-message';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';

interface ChatMsg {
  role: 'user' | 'assistant';
  content: string;
  time: string;
  feedback?: 'up' | 'down';
}

const now = () =>
  new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });

export function ChatPanel() {
  const t = useTranslations('ai');
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [input, setInput] = useState('');
  const [modal, setModal] = useState<{ title: string; answer: string | null } | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const chat = useMutation({
    mutationFn: (payload: { message: string; history: { role: string; content: string }[] }) =>
      api.post<{ reply: string }>('/ai/chat', payload),
  });

  // Quick actions run a distinct contextual query and show it in a modal
  // (kept out of the conversation to stay a focused, closeable side-answer).
  const quickChat = useMutation({
    mutationFn: (payload: { message: string; history: { role: string; content: string }[] }) =>
      api.post<{ reply: string }>('/ai/chat', payload),
  });

  const openQuick = (title: string, instruction: string) => {
    setModal({ title, answer: null });
    const history = messages.map((m) => ({ role: m.role, content: m.content }));
    quickChat.mutate(
      { message: instruction, history },
      {
        onSuccess: (res) => setModal({ title, answer: res.reply }),
        onError: () => setModal({ title, answer: t('networkError') }),
      },
    );
  };

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages, chat.isPending]);

  const send = (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || chat.isPending) return;
    const history = messages.map((m) => ({ role: m.role, content: m.content }));
    setMessages((m) => [...m, { role: 'user', content: trimmed, time: now() }]);
    setInput('');
    chat.mutate(
      { message: trimmed, history },
      {
        onSuccess: (res) =>
          setMessages((m) => [...m, { role: 'assistant', content: res.reply, time: now() }]),
        onError: () =>
          setMessages((m) => [...m, { role: 'assistant', content: t('networkError'), time: now() }]),
      },
    );
  };

  const copy = (text: string) => {
    navigator.clipboard?.writeText(text);
    toast.success(t('copied'));
  };

  const rate = (idx: number, fb: 'up' | 'down') => {
    setMessages((m) => m.map((msg, i) => (i === idx ? { ...msg, feedback: fb } : msg)));
    toast.success(t('feedbackThanks'));
  };

  const suggestions = [t('s1'), t('s2'), t('s3'), t('s4')];
  const quickReplies = [
    { label: t('quickDetails'), icon: Sparkles, instruction: t('quickDetailsPrompt') },
    { label: t('quickAdvice'), icon: Lightbulb, instruction: t('quickAdvicePrompt') },
    { label: t('quickAdjust'), icon: SlidersHorizontal, instruction: t('quickAdjustPrompt') },
  ];

  return (
    <Card className="flex h-[calc(100vh-15rem)] min-h-[460px] flex-col">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-primary/10">
            <Sparkles className="h-4 w-4 text-primary" />
          </span>
          <span className="font-semibold text-foreground">{t('chatTitle')}</span>
        </div>
        {messages.length > 0 && (
          <Button variant="ghost" size="sm" onClick={() => setMessages([])}>
            <Eraser className="h-4 w-4" /> {t('clear')}
          </Button>
        )}
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-5">
        {messages.length === 0 && (
          <div className="space-y-4">
            <div className="flex gap-3">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground">
                <Bot className="h-4 w-4" />
              </span>
              <div className="rounded-2xl bg-muted px-4 py-3 text-sm text-foreground">
                {t('welcome')}
                <p className="mt-1 text-[11px] text-muted-foreground">{now()}</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2 pl-11">
              {suggestions.map((s) => (
                <button
                  key={s}
                  onClick={() => send(s)}
                  className="rounded-full border border-border bg-card px-3 py-1.5 text-xs text-foreground transition-colors hover:bg-accent"
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((m, i) => {
          const isUser = m.role === 'user';
          const isLastAssistant = m.role === 'assistant' && i === messages.length - 1;
          return (
            <div key={i} className={cn('flex gap-3', isUser ? 'flex-row-reverse' : 'flex-row')}>
              <span
                className={cn(
                  'flex h-8 w-8 shrink-0 items-center justify-center rounded-lg',
                  isUser ? 'bg-primary text-primary-foreground' : 'bg-muted text-foreground',
                )}
              >
                {isUser ? <User className="h-4 w-4" /> : <Bot className="h-4 w-4" />}
              </span>
              <div className={cn('min-w-0', isUser ? 'max-w-[85%]' : 'max-w-[92%]')}>
                <div
                  className={cn(
                    'rounded-2xl px-4 py-2.5 text-sm leading-relaxed',
                    isUser
                      ? 'whitespace-pre-wrap bg-primary text-primary-foreground'
                      : 'bg-muted text-foreground',
                  )}
                >
                  {isUser ? m.content : <MarkdownMessage content={m.content} />}
                </div>
                <div
                  className={cn(
                    'mt-1 flex items-center gap-2 px-1 text-[11px] text-muted-foreground',
                    isUser && 'justify-end',
                  )}
                >
                  <span>{m.time}</span>
                  {!isUser && (
                    <>
                      <button
                        onClick={() => copy(m.content)}
                        className="rounded p-0.5 transition-colors hover:text-foreground"
                        title={t('copy')}
                      >
                        <Copy className="h-3.5 w-3.5" />
                      </button>
                      <button
                        onClick={() => rate(i, 'up')}
                        className={cn(
                          'rounded p-0.5 transition-colors hover:text-foreground',
                          m.feedback === 'up' && 'text-success',
                        )}
                        title={t('helpful')}
                      >
                        <ThumbsUp className="h-3.5 w-3.5" />
                      </button>
                      <button
                        onClick={() => rate(i, 'down')}
                        className={cn(
                          'rounded p-0.5 transition-colors hover:text-foreground',
                          m.feedback === 'down' && 'text-destructive',
                        )}
                        title={t('notHelpful')}
                      >
                        <ThumbsDown className="h-3.5 w-3.5" />
                      </button>
                    </>
                  )}
                </div>

                {/* Quick-reply chips under the latest assistant message */}
                {isLastAssistant && !chat.isPending && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {quickReplies.map((q) => {
                      const Icon = q.icon;
                      return (
                        <button
                          key={q.label}
                          onClick={() => openQuick(q.label, q.instruction)}
                          disabled={quickChat.isPending}
                          className="inline-flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1 text-xs text-foreground transition-colors hover:bg-accent disabled:opacity-50"
                        >
                          <Icon className="h-3.5 w-3.5 text-primary" />
                          {q.label}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
          );
        })}

        {chat.isPending && (
          <div className="flex gap-3">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground">
              <Bot className="h-4 w-4" />
            </span>
            <div className="flex items-center gap-2 rounded-2xl bg-muted px-4 py-3 text-sm text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" /> {t('thinking')}
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="border-t border-border p-3">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            send(input);
          }}
          className="flex gap-2"
        >
          <Input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={t('placeholder')}
            disabled={chat.isPending}
          />
          <Button type="submit" size="icon" disabled={chat.isPending || !input.trim()}>
            {chat.isPending ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Send className="h-4 w-4" />
            )}
          </Button>
        </form>
        <p className="mt-2 px-1 text-[11px] text-muted-foreground">{t('disclaimer')}</p>
      </div>

      {/* Quick-action modal */}
      <Dialog open={!!modal} onOpenChange={(o) => !o && setModal(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-primary/10">
                <Sparkles className="h-4 w-4 text-primary" />
              </span>
              {modal?.title}
            </DialogTitle>
          </DialogHeader>
          <div className="max-h-[60vh] min-h-[80px] overflow-y-auto">
            {quickChat.isPending || !modal?.answer ? (
              <div className="flex flex-col items-center justify-center gap-2 py-8 text-center">
                <Loader2 className="h-6 w-6 animate-spin text-primary" />
                <p className="text-sm text-muted-foreground">{t('modalLoading')}</p>
              </div>
            ) : (
              <div className="text-sm">
                <MarkdownMessage content={modal.answer} />
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setModal(null)}>
              {t('close')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
