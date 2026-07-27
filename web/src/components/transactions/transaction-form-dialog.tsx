'use client';

import { useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { Loader2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useCategories } from '@/hooks/use-categories';
import type { Transaction } from '@/lib/types';

export interface TransactionFormValues {
  title: string;
  categoryId: string;
  amount: number;
  date: string;
  description?: string;
  paymentMethod?: string;
  tags?: string;
  isRecurring?: boolean;
}

export function TransactionFormDialog({
  open,
  onOpenChange,
  kind,
  editing,
  onSubmit,
  saving,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  kind: 'INCOME' | 'EXPENSE';
  editing?: Transaction | null;
  onSubmit: (values: TransactionFormValues) => void;
  saving?: boolean;
}) {
  const t = useTranslations('form');
  const tc = useTranslations('common');
  const tt = useTranslations(kind === 'INCOME' ? 'income' : 'expenses');
  const tx = useTranslations('transaction');
  const { data: categories } = useCategories(kind);

  const today = new Date().toISOString().slice(0, 10);
  const {
    register,
    handleSubmit,
    control,
    reset,
    formState: { errors },
  } = useForm<TransactionFormValues>({
    defaultValues: { date: today },
  });

  useEffect(() => {
    if (open) {
      reset(
        editing
          ? {
              title: editing.title,
              categoryId: editing.category.id,
              amount: editing.amount,
              date: editing.date.slice(0, 10),
              description: editing.description ?? '',
              paymentMethod: editing.paymentMethod ?? '',
              tags: editing.tags?.join(', ') ?? '',
              isRecurring: editing.isRecurring ?? false,
            }
          : { title: '', categoryId: '', amount: undefined, date: today, description: '' },
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, editing]);

  const submit = (values: TransactionFormValues) => {
    if (!values.categoryId) {
      toast.error(t('required'));
      return;
    }
    onSubmit(values);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{editing ? tt('edit') : tt('add')}</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit(submit)} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="title">{t('title')}</Label>
            <Input
              id="title"
              placeholder={t('titlePlaceholder')}
              {...register('title', { required: true })}
            />
            {errors.title && <p className="text-xs text-destructive">{t('required')}</p>}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>{t('category')}</Label>
              <Controller
                control={control}
                name="categoryId"
                rules={{ required: true }}
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger>
                      <SelectValue placeholder={t('selectCategory')} />
                    </SelectTrigger>
                    <SelectContent>
                      {(categories ?? []).map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
              {errors.categoryId && <p className="text-xs text-destructive">{t('required')}</p>}
            </div>
            <div className="space-y-2">
              <Label htmlFor="amount">{t('amount')}</Label>
              <Input
                id="amount"
                type="number"
                step="0.01"
                min="0"
                placeholder="0"
                {...register('amount', { required: true, valueAsNumber: true, min: 0 })}
              />
              {errors.amount && <p className="text-xs text-destructive">{t('invalidAmount')}</p>}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="date">{t('date')}</Label>
            <Input id="date" type="date" {...register('date', { required: true })} />
          </div>

          {kind === 'EXPENSE' && (
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label htmlFor="paymentMethod">{t('paymentMethod')}</Label>
                <Input
                  id="paymentMethod"
                  placeholder={t('paymentPlaceholder')}
                  {...register('paymentMethod')}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="tags">{t('tags')}</Label>
                <Input id="tags" placeholder={t('tagsPlaceholder')} {...register('tags')} />
              </div>
            </div>
          )}

          <div className="space-y-2">
            <Label htmlFor="description">{t('description')}</Label>
            <Textarea
              id="description"
              placeholder={t('descriptionPlaceholder')}
              {...register('description')}
            />
          </div>

          {kind === 'INCOME' && (
            <label className="flex items-center gap-2 text-sm text-foreground">
              <input type="checkbox" className="h-4 w-4 rounded border-input" {...register('isRecurring')} />
              {tx('recurring')}
            </label>
          )}

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {tc('cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {saving && <Loader2 className="h-4 w-4 animate-spin" />}
              {tc('save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
