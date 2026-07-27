'use client';

import { useEffect, useState } from 'react';
import { Check, Loader2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { categoryIcon } from '@/lib/category-icons';
import { COLOR_OPTIONS, ICON_OPTIONS } from '@/lib/category-options';
import { cn } from '@/lib/utils';
import type { Category } from '@/lib/types';

export function CategoryFormDialog({
  open,
  onOpenChange,
  type,
  editing,
  onSubmit,
  saving,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  type: 'INCOME' | 'EXPENSE';
  editing?: Category | null;
  onSubmit: (values: { name: string; icon: string; color: string }) => void;
  saving?: boolean;
}) {
  const t = useTranslations('categories');
  const tc = useTranslations('common');

  const [name, setName] = useState('');
  const [icon, setIcon] = useState('circle');
  const [color, setColor] = useState(COLOR_OPTIONS[4]);

  useEffect(() => {
    if (open) {
      setName(editing?.name ?? '');
      setIcon(editing?.icon ?? 'circle');
      setColor(editing?.color ?? COLOR_OPTIONS[4]);
    }
  }, [open, editing]);

  const submit = () => {
    if (!name.trim()) {
      toast.error(tc('save'));
      return;
    }
    onSubmit({ name: name.trim(), icon, color });
  };

  const PreviewIcon = categoryIcon(icon);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{editing ? t('edit') : t('add')}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Preview */}
          <div className="flex items-center gap-3 rounded-xl border border-border bg-muted/40 p-3">
            <span
              className="flex h-11 w-11 items-center justify-center rounded-xl"
              style={{ backgroundColor: `${color}26`, color }}
            >
              <PreviewIcon className="h-5 w-5" />
            </span>
            <span className="font-medium text-foreground">{name || t('name')}</span>
          </div>

          <div className="space-y-2">
            <Label htmlFor="cat-name">{t('name')}</Label>
            <Input id="cat-name" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
          </div>

          <div className="space-y-2">
            <Label>{t('icon')}</Label>
            <div className="grid grid-cols-10 gap-1.5">
              {ICON_OPTIONS.map((ic) => {
                const Ic = categoryIcon(ic);
                return (
                  <button
                    key={ic}
                    type="button"
                    onClick={() => setIcon(ic)}
                    className={cn(
                      'flex h-8 w-8 items-center justify-center rounded-lg border transition-colors',
                      icon === ic
                        ? 'border-primary bg-primary/10 text-primary'
                        : 'border-transparent bg-muted text-muted-foreground hover:bg-accent',
                    )}
                  >
                    <Ic className="h-4 w-4" />
                  </button>
                );
              })}
            </div>
          </div>

          <div className="space-y-2">
            <Label>{t('color')}</Label>
            <div className="grid grid-cols-9 gap-1.5">
              {COLOR_OPTIONS.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setColor(c)}
                  className="flex h-7 w-7 items-center justify-center rounded-full ring-offset-2 ring-offset-background transition-transform hover:scale-110"
                  style={{ backgroundColor: c }}
                >
                  {color === c && <Check className="h-4 w-4 text-white" />}
                </button>
              ))}
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {tc('cancel')}
          </Button>
          <Button onClick={submit} disabled={saving}>
            {saving && <Loader2 className="h-4 w-4 animate-spin" />}
            {tc('save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
